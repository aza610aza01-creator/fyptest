/// Model for `public.workout_sets` supporting all 6 required set types:
/// standard, warmup, superset, drop_set, circuit, amrap.
class WorkoutSetRecord {
  const WorkoutSetRecord({
    required this.id,
    required this.workoutId,
    required this.userId,
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    required this.reps,
    required this.weightKg,
    this.rpe,
    this.rir,
    this.restSeconds = 90,
    this.tempo = '2-0-2-0',
    this.setType = 'standard',
    this.notes = '',
    required this.createdAt,
  });

  static const List<String> supportedSetTypes = [
    'standard',
    'warmup',
    'superset',
    'drop_set',
    'circuit',
    'amrap',
  ];

  final String id;
  final String workoutId;
  final String userId;
  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final int reps;
  final double weightKg;
  final double? rpe;
  final int? rir;
  final int restSeconds;
  final String tempo;
  final String setType;
  final String notes;
  final DateTime createdAt;

  double get volumeKg => weightKg * reps;

  factory WorkoutSetRecord.fromJson(Map<String, dynamic> json) {
    return WorkoutSetRecord(
      id: (json['id'] ?? '').toString(),
      workoutId: (json['workout_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      exerciseId: (json['exercise_id'] ?? '').toString(),
      exerciseName: (json['exercise_name'] ?? 'Exercise').toString(),
      setNumber:
          json['set_number'] is num ? (json['set_number'] as num).toInt() : 1,
      reps: json['reps'] is num ? (json['reps'] as num).toInt() : 0,
      weightKg: json['weight_kg'] is num
          ? (json['weight_kg'] as num).toDouble()
          : 0.0,
      rpe: json['rpe'] is num ? (json['rpe'] as num).toDouble() : null,
      rir: json['rir'] is num ? (json['rir'] as num).toInt() : null,
      restSeconds: json['rest_seconds'] is num
          ? (json['rest_seconds'] as num).toInt()
          : 90,
      tempo: (json['tempo'] ?? '').toString(),
      setType: (json['set_type'] ?? 'standard').toString(),
      notes: (json['notes'] ?? '').toString(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson({bool includeExerciseName = true}) {
    final map = <String, dynamic>{
      'id': id,
      'workout_id': workoutId,
      'user_id': userId,
      'exercise_id': exerciseId,
      'set_number': setNumber,
      'reps': reps,
      'weight_kg': weightKg,
      'rpe': rpe,
      'rir': rir,
      'rest_seconds': restSeconds,
      'tempo': tempo,
      'set_type': setType,
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (includeExerciseName) {
      map['exercise_name'] = exerciseName;
    }
    return map;
  }

  WorkoutSetRecord copyWith({
    String? exerciseId,
    String? exerciseName,
    int? setNumber,
    int? reps,
    double? weightKg,
    double? rpe,
    int? rir,
    int? restSeconds,
    String? tempo,
    String? setType,
    String? notes,
  }) {
    return WorkoutSetRecord(
      id: id,
      workoutId: workoutId,
      userId: userId,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      rpe: rpe ?? this.rpe,
      rir: rir ?? this.rir,
      restSeconds: restSeconds ?? this.restSeconds,
      tempo: tempo ?? this.tempo,
      setType: setType ?? this.setType,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}
