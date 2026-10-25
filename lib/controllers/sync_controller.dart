import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/models/health_and_coaching_models.dart';
import 'package:ai_gym_flutter/models/routine.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/models/workout_set.dart';
import 'package:ai_gym_flutter/repositories/detection_repository.dart';
import 'package:ai_gym_flutter/repositories/measurement_repository.dart';
import 'package:ai_gym_flutter/repositories/workout_repository.dart';
import 'package:ai_gym_flutter/services/database_service.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Summary of an idempotent Guest-to-Cloud migration operation.
@immutable
class GuestMigrationReport {
  const GuestMigrationReport({
    required this.workoutsMigrated,
    required this.routinesMigrated,
    required this.measurementsMigrated,
    required this.healthLogsMigrated,
    required this.detectionsMigrated,
    required this.goalsMigrated,
    required this.failedCount,
  });

  final int workoutsMigrated;
  final int routinesMigrated;
  final int measurementsMigrated;
  final int healthLogsMigrated;
  final int detectionsMigrated;
  final int goalsMigrated;
  final int failedCount;

  int get totalMigrated =>
      workoutsMigrated +
      routinesMigrated +
      measurementsMigrated +
      healthLogsMigrated +
      detectionsMigrated +
      goalsMigrated;

  bool get isCompleteSuccess => failedCount == 0;
}

/// Manages global offline queue state, bounded exponential backoff with jitter,
/// conflict-safe cloud sync, and idempotent Guest-to-Cloud data migration.
class SyncController extends ChangeNotifier {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  SyncController({
    required this.db,
    required this.prefs,
    required this.workoutRepo,
    required this.measurementRepo,
    required this.detectionRepo,
    required this.diagnostics,
  });

  final DatabaseService db;
  final PreferenceService prefs;
  final WorkoutRepository workoutRepo;
  final MeasurementRepository measurementRepo;
  final DetectionRepository detectionRepo;
  final DiagnosticsService diagnostics;

  bool _isSyncing = false;
  int _failedItemCount = 0;
  int _retryAttempt = 0;
  String? _lastErrorReason;
  DateTime? _lastSyncedAtUtc;

  bool get isSyncing => _isSyncing;
  bool get isOnline => db.isConnected;
  int get pendingCount => prefs.getOfflineWorkoutQueue().length;
  int get failedItemCount => _failedItemCount;
  int get retryAttempt => _retryAttempt;
  String? get lastErrorReason => _lastErrorReason;
  DateTime? get lastSyncedAtUtc => _lastSyncedAtUtc;

  /// Computes bounded exponential backoff with deterministic/optional jitter (in ms).
  Duration computeBackoffDelay(int attempt, {double jitterFactor = 0.15}) {
    final clampedAttempt = attempt.clamp(0, 6);
    final baseMs = 1000 * (1 << clampedAttempt); // 1s, 2s, 4s, 8s, 16s, 32s, 64s
    final cappedMs = math.min(baseMs, 60000);
    final jitter = (cappedMs * jitterFactor).round();
    return Duration(milliseconds: cappedMs + jitter);
  }

  /// Flushes pending offline operations and updates global sync state.
  Future<int> syncPendingOperations({
    required String userId,
    required bool isGuest,
  }) async {
    if (_isSyncing) return 0;
    if (isGuest || db.client == null) {
      _lastErrorReason = isGuest
          ? 'Guest Mode stores records locally until upgraded.'
          : 'Cloud database client offline.';
      notifyListeners();
      return 0;
    }

    _isSyncing = true;
    _lastErrorReason = null;
    notifyListeners();

    try {
      final synced = await workoutRepo.syncPendingQueue(isGuest: isGuest);
      final remaining = prefs.getOfflineWorkoutQueue().length;
      _failedItemCount = remaining;
      if (remaining == 0) {
        _retryAttempt = 0;
        _lastSyncedAtUtc = DateTime.now().toUtc();
      } else {
        _retryAttempt += 1;
        _lastErrorReason = '$remaining item(s) could not be synced yet.';
      }
      _isSyncing = false;
      notifyListeners();
      return synced;
    } catch (e) {
      _retryAttempt += 1;
      _failedItemCount = prefs.getOfflineWorkoutQueue().length;
      _lastErrorReason = e.runtimeType.toString();
      _isSyncing = false;
      diagnostics.logEvent('SyncController retry #$_retryAttempt failed: ${e.runtimeType}');
      notifyListeners();
      return 0;
    }
  }

  /// Idempotently migrates local Guest workouts, routines, body measurements,
  /// health logs, goals, and saved camera detections to a newly verified cloud user.
  Future<GuestMigrationReport> migrateGuestDataToAccount({
    required String verifiedUserId,
  }) async {
    _isSyncing = true;
    notifyListeners();

    int workoutsCount = 0;
    int routinesCount = 0;
    int measurementsCount = 0;
    int healthCount = 0;
    int detectionsCount = 0;
    int goalsCount = 0;
    int failures = 0;

    try {
      for (final w in prefs.getLocalWorkouts()) {
        try {
          final reassignedSets = w.sets
              .map(
                (s) => WorkoutSetRecord(
                  id: s.id,
                  workoutId: w.id,
                  userId: verifiedUserId,
                  exerciseId: s.exerciseId,
                  exerciseName: s.exerciseName,
                  setNumber: s.setNumber,
                  reps: s.reps,
                  weightKg: s.weightKg,
                  rpe: s.rpe,
                  rir: s.rir,
                  restSeconds: s.restSeconds,
                  tempo: s.tempo,
                  setType: s.setType,
                  notes: s.notes,
                  createdAt: s.createdAt,
                ),
              )
              .toList();
          final reassigned = WorkoutRecord(
            id: w.id,
            userId: verifiedUserId,
            routineId: w.routineId,
            title: w.title,
            workoutType: w.workoutType,
            startedAt: w.startedAt,
            endedAt: w.endedAt,
            notes: w.notes,
            syncedAt: DateTime.now().toUtc(),
            createdAt: w.createdAt,
            sets: reassignedSets,
            isPendingSync: false,
          );
          await workoutRepo.saveWorkout(workout: reassigned, isGuest: false);
          workoutsCount++;
        } catch (_) {
          failures++;
        }
      }

      for (final r in prefs.getLocalRoutines()) {
        try {
          final reassigned = WorkoutRoutine(
            id: r.id,
            userId: verifiedUserId,
            name: r.name,
            description: r.description,
            workoutMethod: r.workoutMethod,
            items: r.items,
            createdAt: r.createdAt,
          );
          await workoutRepo.saveRoutine(routine: reassigned, isGuest: false);
          routinesCount++;
        } catch (_) {
          failures++;
        }
      }

      for (final m in prefs.getLocalMeasurements()) {
        try {
          final reassigned = BodyMeasurement(
            id: m.id,
            userId: verifiedUserId,
            recordedAt: m.recordedAt,
            weightKg: m.weightKg,
            bodyFatPercent: m.bodyFatPercent,
            chestCm: m.chestCm,
            waistCm: m.waistCm,
            armsCm: m.armsCm,
            thighsCm: m.thighsCm,
            photoPath: m.photoPath,
          );
          await measurementRepo.saveMeasurement(
            measurement: reassigned,
            isGuest: false,
          );
          measurementsCount++;
        } catch (_) {
          failures++;
        }
      }

      for (final h in prefs.getLocalHealthLogs()) {
        try {
          final reassigned = HealthLogRecord(
            id: h.id,
            userId: verifiedUserId,
            recordedDate: h.recordedDate,
            waterMl: h.waterMl,
            sleepHours: h.sleepHours,
            steps: h.steps,
            calories: h.calories,
            proteinG: h.proteinG,
            carbsG: h.carbsG,
            fatG: h.fatG,
            restingHeartRate: h.restingHeartRate,
          );
          await measurementRepo.saveHealthLog(log: reassigned, isGuest: false);
          healthCount++;
        } catch (_) {
          failures++;
        }
      }

      for (final g in prefs.getLocalGoals()) {
        try {
          final reassigned = UserGoalRecord(
            id: g.id,
            userId: verifiedUserId,
            goalType: g.goalType,
            targetValue: g.targetValue,
            currentValue: g.currentValue,
            targetDate: g.targetDate,
            status: g.status,
          );
          await workoutRepo.saveGoal(goal: reassigned, isGuest: false);
          goalsCount++;
        } catch (_) {
          failures++;
        }
      }

      for (final d in prefs.getLocalDetections()) {
        try {
          final reassigned = CameraDetectionRecord(
            id: d.id,
            userId: verifiedUserId,
            label: d.label,
            confidence: d.confidence,
            boundingBox: d.boundingBox,
            sourceWidth: d.sourceWidth,
            sourceHeight: d.sourceHeight,
            detectedAt: d.detectedAt,
            detectionEngine: d.detectionEngine,
            classId: d.classId,
            inferenceMs: d.inferenceMs,
            suggestedExercise: d.suggestedExercise,
            imagePath: d.imagePath,
            isSavedToCloud: true,
          );
          await detectionRepo.saveDetection(
            detection: reassigned,
            isGuest: false,
          );
          detectionsCount++;
        } catch (_) {
          failures++;
        }
      }
    } finally {
      _isSyncing = false;
      _lastSyncedAtUtc = DateTime.now().toUtc();
      notifyListeners();
    }

    return GuestMigrationReport(
      workoutsMigrated: workoutsCount,
      routinesMigrated: routinesCount,
      measurementsMigrated: measurementsCount,
      healthLogsMigrated: healthCount,
      detectionsMigrated: detectionsCount,
      goalsMigrated: goalsCount,
      failedCount: failures,
    );
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
