import 'package:ai_gym_flutter/models/health_and_coaching_models.dart';
import 'package:ai_gym_flutter/models/routine.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/models/workout_set.dart';
import 'package:ai_gym_flutter/services/database_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Repository for `workouts`, `workout_sets`, `routines`, `routine_exercises`,
/// `cardio_logs`, and `user_goals`.
/// Implements offline queueing and conflict-safe cloud sync (Section 20).
class WorkoutRepository {
  WorkoutRepository({
    required this.db,
    required this.prefs,
  });

  final DatabaseService db;
  final PreferenceService prefs;

  Future<List<WorkoutRecord>> fetchWorkouts({
    required String userId,
    required bool isGuest,
  }) async {
    final localList = prefs.getLocalWorkouts();
    final queueList = prefs.getOfflineWorkoutQueue();

    if (isGuest || db.client == null) {
      return _mergeWorkouts(localList, queueList);
    }

    try {
      final workoutRows = await db.client!
          .from('workouts')
          .select()
          .eq('user_id', userId)
          .order('started_at', ascending: false)
          .limit(50);

      final setRows = await db.client!
          .from('workout_sets')
          .select()
          .eq('user_id', userId)
          .order('set_number', ascending: true);

      final setsByWorkout = <String, List<WorkoutSetRecord>>{};
      for (final raw in (setRows as List).whereType<Map<String, dynamic>>()) {
        final setRec = WorkoutSetRecord.fromJson(raw);
        setsByWorkout.putIfAbsent(setRec.workoutId, () => <WorkoutSetRecord>[]).add(setRec);
      }

      final cloudWorkouts = <WorkoutRecord>[];
      for (final raw in (workoutRows as List).whereType<Map<String, dynamic>>()) {
        final base = WorkoutRecord.fromJson(raw);
        cloudWorkouts.add(
          base.copyWith(
            sets: setsByWorkout[base.id] ?? const <WorkoutSetRecord>[],
            isPendingSync: false,
          ),
        );
      }

      await prefs.saveLocalWorkouts(cloudWorkouts);
      return _mergeWorkouts(cloudWorkouts, queueList);
    } catch (e) {
      db.diagnostics.logEvent('Workouts offline fallback (${e.runtimeType})');
      return _mergeWorkouts(localList, queueList);
    }
  }

  /// Saves a completed workout to Supabase, or queues it locally if offline/Guest.
  Future<WorkoutRecord> saveWorkout({
    required WorkoutRecord workout,
    required bool isGuest,
  }) async {
    final local = prefs.getLocalWorkouts();
    final updatedLocal = [
      workout,
      ...local.where((w) => w.id != workout.id),
    ];
    await prefs.saveLocalWorkouts(updatedLocal);

    if (isGuest || db.client == null) {
      return workout;
    }

    try {
      await _uploadWorkoutConflictSafe(workout);
      final synced = workout.copyWith(
        syncedAt: DateTime.now().toUtc(),
        isPendingSync: false,
      );
      await prefs.setLastSyncState(
        'Synced workout "${workout.title}" at ${DateTime.now().toUtc().toIso8601String()}',
      );
      return synced;
    } catch (e) {
      db.diagnostics.logEvent('Queued workout offline due to ${e.runtimeType}');
      final pending = workout.copyWith(isPendingSync: true);
      final queue = prefs.getOfflineWorkoutQueue();
      await prefs.saveOfflineWorkoutQueue([
        pending,
        ...queue.where((w) => w.id != pending.id),
      ]);
      await prefs.setLastSyncState(
        'Offline queue (${queue.length + 1} pending)',
      );
      return pending;
    }
  }

  /// Flushes the offline workout queue without overwriting newer cloud records.
  Future<int> syncPendingQueue({required bool isGuest}) async {
    if (isGuest || db.client == null) return 0;
    final queue = prefs.getOfflineWorkoutQueue();
    if (queue.isEmpty) return 0;

    final remaining = <WorkoutRecord>[];
    int syncedCount = 0;

    for (final item in queue) {
      try {
        await _uploadWorkoutConflictSafe(item);
        syncedCount += 1;
      } catch (_) {
        remaining.add(item);
      }
    }

    await prefs.saveOfflineWorkoutQueue(remaining);
    await prefs.setLastSyncState(
      remaining.isEmpty
          ? 'All records synced (${DateTime.now().toUtc().toIso8601String()})'
          : '${remaining.length} record(s) still awaiting connection',
    );
    return syncedCount;
  }

  /// Conflict-safe upload: checks cloud `synced_at` before updating so an older
  /// local draft never overwrites a newer cloud record (Section 20).
  Future<void> _uploadWorkoutConflictSafe(WorkoutRecord workout) async {
    final client = db.client!;
    final existing = await client
        .from('workouts')
        .select('id, synced_at')
        .eq('id', workout.id)
        .maybeSingle();

    if (existing != null && existing['synced_at'] != null) {
      final cloudSyncedAt = DateTime.tryParse(existing['synced_at'].toString());
      final localTime = workout.endedAt ?? workout.startedAt;
      if (cloudSyncedAt != null && cloudSyncedAt.isAfter(localTime)) {
        db.diagnostics.logEvent(
          'Skipped overwriting newer cloud workout ${workout.id}',
        );
        return;
      }
    }

    await client.from('workouts').upsert(workout.toDatabaseRow());

    if (workout.sets.isNotEmpty) {
      final setRows = workout.sets
          .map((s) => s.toJson(includeExerciseName: false))
          .toList();
      await client.from('workout_sets').upsert(setRows);
    }
  }

  Future<List<WorkoutRoutine>> fetchRoutines({
    required String userId,
    required bool isGuest,
  }) async {
    final local = prefs.getLocalRoutines();
    if (isGuest || db.client == null) return local;
    try {
      final rows = await db.client!
          .from('routines')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final parsed = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(WorkoutRoutine.fromJson)
          .toList();
      if (parsed.isNotEmpty) {
        await prefs.saveLocalRoutines(parsed);
        return parsed;
      }
      return local;
    } catch (_) {
      return local;
    }
  }

  Future<void> saveRoutine({
    required WorkoutRoutine routine,
    required bool isGuest,
  }) async {
    final existing = prefs.getLocalRoutines();
    final updated = [routine, ...existing.where((r) => r.id != routine.id)];
    await prefs.saveLocalRoutines(updated);

    if (isGuest || db.client == null) return;
    try {
      await db.client!.from('routines').upsert({
        'id': routine.id,
        'user_id': routine.userId,
        'name': routine.name,
        'description': routine.description,
        'workout_method': routine.workoutMethod,
      });
    } catch (e) {
      db.diagnostics.logEvent('Routine saved locally; cloud sync deferred.');
    }
  }

  Future<void> saveCardioLog({
    required CardioLogRecord log,
    required bool isGuest,
  }) async {
    if (isGuest || db.client == null) return;
    try {
      await db.client!.from('cardio_logs').upsert(log.toJson());
    } catch (e) {
      db.diagnostics.logEvent('Cardio log cloud upload deferred (${e.runtimeType})');
    }
  }

  Future<List<UserGoalRecord>> fetchGoals({
    required String userId,
    required bool isGuest,
  }) async {
    final local = prefs.getLocalGoals();
    if (isGuest || db.client == null) return local;
    try {
      final rows = await db.client!
          .from('user_goals')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final parsed = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(UserGoalRecord.fromJson)
          .toList();
      if (parsed.isNotEmpty) {
        await prefs.saveLocalGoals(parsed);
        return parsed;
      }
      return local;
    } catch (_) {
      return local;
    }
  }

  Future<void> saveGoal({
    required UserGoalRecord goal,
    required bool isGuest,
  }) async {
    final local = prefs.getLocalGoals();
    final updated = [goal, ...local.where((g) => g.id != goal.id)];
    await prefs.saveLocalGoals(updated);

    if (isGuest || db.client == null) return;
    try {
      await db.client!.from('user_goals').upsert(goal.toJson());
    } catch (_) {}
  }

  List<WorkoutRecord> _mergeWorkouts(
    List<WorkoutRecord> primary,
    List<WorkoutRecord> queue,
  ) {
    final byId = <String, WorkoutRecord>{};
    for (final w in primary) {
      byId[w.id] = w;
    }
    for (final q in queue) {
      byId[q.id] = q.copyWith(isPendingSync: true);
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return merged;
  }
}
