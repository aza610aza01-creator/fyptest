/// Models for `public.routines` and `public.routine_exercises`.
class RoutineExerciseItem {
  const RoutineExerciseItem({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    required this.exerciseName,
    required this.ordering,
    this.targetSets = 3,
    this.targetReps = 10,
    this.targetWeightKg = 20,
    this.restSeconds = 90,
    this.tempo = '2-0-2-0',
    this.notes = '',
  });

  final String id;
  final String routineId;
  final String exerciseId;
  final String exerciseName;
  final int ordering;
  final int targetSets;
  final int targetReps;
  final double targetWeightKg;
  final int restSeconds;
  final String tempo;
  final String notes;

  factory RoutineExerciseItem.fromJson(Map<String, dynamic> json) {
    return RoutineExerciseItem(
      id: (json['id'] ?? '').toString(),
      routineId: (json['routine_id'] ?? '').toString(),
      exerciseId: (json['exercise_id'] ?? '').toString(),
      exerciseName: (json['exercise_name'] ?? 'Exercise').toString(),
      ordering: json['ordering'] is num ? (json['ordering'] as num).toInt() : 1,
      targetSets:
          json['target_sets'] is num ? (json['target_sets'] as num).toInt() : 3,
      targetReps:
          json['target_reps'] is num ? (json['target_reps'] as num).toInt() : 10,
      targetWeightKg: json['target_weight_kg'] is num
          ? (json['target_weight_kg'] as num).toDouble()
          : 0,
      restSeconds: json['rest_seconds'] is num
          ? (json['rest_seconds'] as num).toInt()
          : 90,
      tempo: (json['tempo'] ?? '2-0-2-0').toString(),
      notes: (json['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routine_id': routineId,
      'exercise_id': exerciseId,
      'ordering': ordering,
      'target_sets': targetSets,
      'target_reps': targetReps,
      'target_weight_kg': targetWeightKg,
      'rest_seconds': restSeconds,
      'tempo': tempo,
      'notes': notes,
    };
  }
}

class WorkoutRoutine {
  const WorkoutRoutine({
    required this.id,
    required this.userId,
    required this.name,
    this.description = '',
    this.workoutMethod = 'standard',
    this.items = const <RoutineExerciseItem>[],
    this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String description;
  final String workoutMethod;
  final List<RoutineExerciseItem> items;
  final DateTime? createdAt;

  factory WorkoutRoutine.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final parsedItems = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(RoutineExerciseItem.fromJson)
            .toList()
        : <RoutineExerciseItem>[];

    return WorkoutRoutine(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      workoutMethod: (json['workout_method'] ?? 'standard').toString(),
      items: parsedItems,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'workout_method': workoutMethod,
      'items': items.map((e) => e.toJson()).toList(),
      'created_at': (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
    };
  }
}
