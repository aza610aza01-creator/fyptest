import 'package:flutter/foundation.dart';
import 'package:ai_gym_flutter/core/errors/app_failure.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/models/exercise.dart';
import 'package:ai_gym_flutter/models/health_and_coaching_models.dart';
import 'package:ai_gym_flutter/models/routine.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/repositories/detection_repository.dart';
import 'package:ai_gym_flutter/repositories/exercise_repository.dart';
import 'package:ai_gym_flutter/repositories/measurement_repository.dart';
import 'package:ai_gym_flutter/repositories/profile_repository.dart';
import 'package:ai_gym_flutter/repositories/workout_repository.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';

/// Strongly-typed immutable snapshot of all initial user domain collections.
/// Eliminates fragile `results[0] as ...` untyped `Future.wait` index casts.
@immutable
class InitialUserData {
  const InitialUserData({
    required this.userId,
    required this.profile,
    required this.exercises,
    required this.workouts,
    required this.routines,
    required this.goals,
    required this.measurements,
    required this.healthLogs,
    required this.detections,
    required this.loadedAtUtc,
    this.isOfflineFallback = false,
  });

  final String userId;
  final UserProfile profile;
  final List<Exercise> exercises;
  final List<WorkoutRecord> workouts;
  final List<WorkoutRoutine> routines;
  final List<UserGoalRecord> goals;
  final List<BodyMeasurement> measurements;
  final List<HealthLogRecord> healthLogs;
  final List<CameraDetectionRecord> detections;
  final DateTime loadedAtUtc;
  final bool isOfflineFallback;

  InitialUserData copyWith({
    UserProfile? profile,
    List<Exercise>? exercises,
    List<WorkoutRecord>? workouts,
    List<WorkoutRoutine>? routines,
    List<UserGoalRecord>? goals,
    List<BodyMeasurement>? measurements,
    List<HealthLogRecord>? healthLogs,
    List<CameraDetectionRecord>? detections,
    bool? isOfflineFallback,
  }) {
    return InitialUserData(
      userId: userId,
      profile: profile ?? this.profile,
      exercises: List<Exercise>.unmodifiable(exercises ?? this.exercises),
      workouts: List<WorkoutRecord>.unmodifiable(workouts ?? this.workouts),
      routines: List<WorkoutRoutine>.unmodifiable(routines ?? this.routines),
      goals: List<UserGoalRecord>.unmodifiable(goals ?? this.goals),
      measurements:
          List<BodyMeasurement>.unmodifiable(measurements ?? this.measurements),
      healthLogs:
          List<HealthLogRecord>.unmodifiable(healthLogs ?? this.healthLogs),
      detections: List<CameraDetectionRecord>.unmodifiable(
        detections ?? this.detections,
      ),
      loadedAtUtc: DateTime.now().toUtc(),
      isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
    );
  }
}

/// Manages typed user data loading, request-generation token cancellation
/// (preventing stale account data races), and immutable in-memory updates.
class UserDataController extends ChangeNotifier {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  UserDataController({
    required this.profileRepo,
    required this.exerciseRepo,
    required this.workoutRepo,
    required this.measurementRepo,
    required this.detectionRepo,
    required this.diagnostics,
  });

  final ProfileRepository profileRepo;
  final ExerciseRepository exerciseRepo;
  final WorkoutRepository workoutRepo;
  final MeasurementRepository measurementRepo;
  final DetectionRepository detectionRepo;
  final DiagnosticsService diagnostics;

  InitialUserData? _data;
  AppFailure? _loadFailure;
  bool _isLoading = false;
  int _requestGeneration = 0;
  String _activeUserId = '';

  InitialUserData? get data => _data;
  AppFailure? get loadFailure => _loadFailure;
  bool get isLoading => _isLoading;
  String get activeUserId => _activeUserId;

  UserProfile? get profile => _data?.profile;
  List<Exercise> get exercises => _data?.exercises ?? const <Exercise>[];
  List<WorkoutRecord> get workouts =>
      _data?.workouts ?? const <WorkoutRecord>[];
  List<WorkoutRoutine> get routines =>
      _data?.routines ?? const <WorkoutRoutine>[];
  List<UserGoalRecord> get goals => _data?.goals ?? const <UserGoalRecord>[];
  List<BodyMeasurement> get measurements =>
      _data?.measurements ?? const <BodyMeasurement>[];
  List<HealthLogRecord> get healthLogs =>
      _data?.healthLogs ?? const <HealthLogRecord>[];
  List<CameraDetectionRecord> get detections =>
      _data?.detections ?? const <CameraDetectionRecord>[];

  /// Loads all initial user data using typed futures and generation-token
  /// cancellation so rapid account switches never overwrite newer user state.
  Future<AppResult<InitialUserData>> loadForUser(
    AppUser user, {
    bool forceReload = false,
  }) async {
    if (!forceReload &&
        _data != null &&
        _activeUserId == user.id &&
        _loadFailure == null) {
      return AppResult.success(_data!);
    }

    final int generation = ++_requestGeneration;
    _activeUserId = user.id;
    _isLoading = true;
    _loadFailure = null;
    notifyListeners();

    try {
      final profileFuture = profileRepo.fetchOrCreateProfile(
        userId: user.id,
        defaultDisplayName: user.email.split('@').first,
        isGuest: user.isGuest,
      );
      final exercisesFuture = exerciseRepo.fetchExercises(isGuest: user.isGuest);
      final workoutsFuture = workoutRepo.fetchWorkouts(
        userId: user.id,
        isGuest: user.isGuest,
      );
      final routinesFuture = workoutRepo.fetchRoutines(
        userId: user.id,
        isGuest: user.isGuest,
      );
      final goalsFuture = workoutRepo.fetchGoals(
        userId: user.id,
        isGuest: user.isGuest,
      );
      final measurementsFuture = measurementRepo.fetchMeasurements(
        userId: user.id,
        isGuest: user.isGuest,
      );
      final healthLogsFuture = measurementRepo.fetchHealthLogs(
        userId: user.id,
        isGuest: user.isGuest,
      );
      final detectionsFuture = detectionRepo.fetchSavedDetections(
        userId: user.id,
        isGuest: user.isGuest,
      );

      final loadedProfile = await profileFuture;
      final loadedExercises = await exercisesFuture;
      final loadedWorkouts = await workoutsFuture;
      final loadedRoutines = await routinesFuture;
      final loadedGoals = await goalsFuture;
      final loadedMeasurements = await measurementsFuture;
      final loadedHealthLogs = await healthLogsFuture;
      final loadedDetections = await detectionsFuture;

      if (generation != _requestGeneration) {
        return AppResult.failure(
          const AppFailure(
            kind: AppFailureKind.unknown,
            code: 'STALE_REQUEST',
            messageEn: 'Superseded by a newer user session.',
            messageZh: '已被較新的使用者工作階段取代。',
          ),
        );
      }

      final snapshot = InitialUserData(
        userId: user.id,
        profile: loadedProfile,
        exercises: List<Exercise>.unmodifiable(loadedExercises),
        workouts: List<WorkoutRecord>.unmodifiable(loadedWorkouts),
        routines: List<WorkoutRoutine>.unmodifiable(loadedRoutines),
        goals: List<UserGoalRecord>.unmodifiable(loadedGoals),
        measurements: List<BodyMeasurement>.unmodifiable(loadedMeasurements),
        healthLogs: List<HealthLogRecord>.unmodifiable(loadedHealthLogs),
        detections: List<CameraDetectionRecord>.unmodifiable(loadedDetections),
        loadedAtUtc: DateTime.now().toUtc(),
      );

      _data = snapshot;
      _isLoading = false;
      _loadFailure = null;
      notifyListeners();
      return AppResult.success(snapshot);
    } catch (e) {
      if (generation != _requestGeneration) {
        return AppResult.failure(AppFailure.fromException(e));
      }
      diagnostics.logEvent('InitialUserData load error: ${e.runtimeType}');
      final failure = AppFailure.fromException(e, fallbackCode: 'INIT_LOAD_ERR');
      _isLoading = false;
      _loadFailure = failure;
      notifyListeners();
      return AppResult.failure(failure);
    }
  }

  /// Allows the athlete to continue with local/cached offline seed data if cloud
  /// initial loading fails due to connectivity.
  void continueWithOfflineFallback(AppUser user) {
    final fallbackProfile = profileRepo.prefs.getGuestProfile() ??
        UserProfile(
          id: user.id,
          displayName: user.email.isNotEmpty
              ? user.email.split('@').first
              : 'Offline Athlete',
          language: profileRepo.prefs.languageCode,
          unitSystem: profileRepo.prefs.unitSystem,
          onboardingCompleted: true,
        );

    _data = InitialUserData(
      userId: user.id,
      profile: fallbackProfile,
      exercises: List<Exercise>.unmodifiable(Exercise.defaultSeedExercises()),
      workouts: List<WorkoutRecord>.unmodifiable(
        profileRepo.prefs.getLocalWorkouts(),
      ),
      routines: List<WorkoutRoutine>.unmodifiable(
        profileRepo.prefs.getLocalRoutines(),
      ),
      goals: List<UserGoalRecord>.unmodifiable(
        profileRepo.prefs.getLocalGoals(),
      ),
      measurements: List<BodyMeasurement>.unmodifiable(
        profileRepo.prefs.getLocalMeasurements(),
      ),
      healthLogs: List<HealthLogRecord>.unmodifiable(
        profileRepo.prefs.getLocalHealthLogs(),
      ),
      detections: List<CameraDetectionRecord>.unmodifiable(
        profileRepo.prefs.getLocalDetections(),
      ),
      loadedAtUtc: DateTime.now().toUtc(),
      isOfflineFallback: true,
    );
    _loadFailure = null;
    _isLoading = false;
    notifyListeners();
  }

  void updateProfileInMemory(UserProfile updated) {
    final current = _data;
    if (current == null) return;
    _data = current.copyWith(profile: updated);
    notifyListeners();
  }

  void upsertWorkoutInMemory(WorkoutRecord saved) {
    final current = _data;
    if (current == null) return;
    final next = <WorkoutRecord>[
      saved,
      ...current.workouts.where((w) => w.id != saved.id),
    ];
    _data = current.copyWith(workouts: next);
    notifyListeners();
  }

  void replaceWorkoutsInMemory(List<WorkoutRecord> refreshed) {
    final current = _data;
    if (current == null) return;
    _data = current.copyWith(workouts: refreshed);
    notifyListeners();
  }

  void upsertRoutineInMemory(WorkoutRoutine routine) {
    final current = _data;
    if (current == null) return;
    final next = <WorkoutRoutine>[
      routine,
      ...current.routines.where((r) => r.id != routine.id),
    ];
    _data = current.copyWith(routines: next);
    notifyListeners();
  }

  void deleteRoutineInMemory(String routineId) {
    final current = _data;
    if (current == null) return;
    final next = current.routines.where((r) => r.id != routineId).toList();
    _data = current.copyWith(routines: next);
    notifyListeners();
  }

  void upsertGoalInMemory(UserGoalRecord goal) {
    final current = _data;
    if (current == null) return;
    final next = <UserGoalRecord>[
      goal,
      ...current.goals.where((g) => g.id != goal.id),
    ];
    _data = current.copyWith(goals: next);
    notifyListeners();
  }

  void upsertMeasurementInMemory(BodyMeasurement measurement) {
    final current = _data;
    if (current == null) return;
    final next = <BodyMeasurement>[
      measurement,
      ...current.measurements.where((m) => m.id != measurement.id),
    ];
    _data = current.copyWith(measurements: next);
    notifyListeners();
  }

  void upsertHealthLogInMemory(HealthLogRecord log) {
    final current = _data;
    if (current == null) return;
    final next = <HealthLogRecord>[
      log,
      ...current.healthLogs.where((h) => h.recordedDate != log.recordedDate),
    ];
    _data = current.copyWith(healthLogs: next);
    notifyListeners();
  }

  void upsertDetectionInMemory(CameraDetectionRecord detection) {
    final current = _data;
    if (current == null) return;
    final next = <CameraDetectionRecord>[
      detection,
      ...current.detections.where((d) => d.id != detection.id),
    ];
    _data = current.copyWith(detections: next);
    notifyListeners();
  }

  void resetOnSignOut() {
    _requestGeneration++;
    _activeUserId = '';
    _data = null;
    _loadFailure = null;
    _isLoading = false;
    notifyListeners();
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
