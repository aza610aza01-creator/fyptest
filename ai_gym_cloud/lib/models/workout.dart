import 'package:ai_gym_flutter/models/workout_set.dart';

/// Model for `public.workouts` with nested `WorkoutSetRecord` items and sync state.
class WorkoutRecord {
  const WorkoutRecord({
    required this.id,
    required this.userId,
    this.routineId,
    required this.title,
    this.workoutType = 'strength',
    required this.startedAt,
    this.endedAt,
    this.notes = '',
    this.syncedAt,
    required this.createdAt,
    this.sets = const <WorkoutSetRecord>[],
    this.isPendingSync = false,
  });

  final String id;
  final String userId;
  final String? routineId;
  final String title;
  final String workoutType;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String notes;
  final DateTime? syncedAt;
  final DateTime createdAt;
  final List<WorkoutSetRecord> sets;
  final bool isPendingSync;

  double get totalVolumeKg =>
      sets.fold<double>(0, (sum, item) => sum + item.volumeKg);

  int get totalReps => sets.fold<int>(0, (sum, item) => sum + item.reps);

  int get durationMinutes {
    final end = endedAt ?? DateTime.now().toUtc();
    final diff = end.difference(startedAt).inMinutes;
    return diff < 1 ? 1 : diff;
  }

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] ?? json['workout_sets'];
    final parsedSets = rawSets is List
        ? rawSets
            .whereType<Map<String, dynamic>>()
            .map(WorkoutSetRecord.fromJson)
            .toList()
        : <WorkoutSetRecord>[];

    return WorkoutRecord(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      routineId: json['routine_id']?.toString(),
      title: (json['title'] ?? 'Workout Session').toString(),
      workoutType: (json['workout_type'] ?? 'strength').toString(),
      startedAt: json['started_at'] != null
          ? (DateTime.tryParse(json['started_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
      notes: (json['notes'] ?? '').toString(),
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      sets: parsedSets,
      isPendingSync: json['is_pending_sync'] == true,
    );
  }

  Map<String, dynamic> toDatabaseRow() {
    return {
      'id': id,
      'user_id': userId,
      'routine_id': routineId,
      'title': title,
      'workout_type': workoutType,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'notes': notes,
      'synced_at': (syncedAt ?? DateTime.now().toUtc()).toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      ...toDatabaseRow(),
      'sets': sets.map((s) => s.toJson()).toList(),
      'is_pending_sync': isPendingSync,
    };
  }

  WorkoutRecord copyWith({
    String? title,
    String? workoutType,
    DateTime? endedAt,
    String? notes,
    DateTime? syncedAt,
    List<WorkoutSetRecord>? sets,
    bool? isPendingSync,
  }) {
    return WorkoutRecord(
      id: id,
      userId: userId,
      routineId: routineId,
      title: title ?? this.title,
      workoutType: workoutType ?? this.workoutType,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      notes: notes ?? this.notes,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt,
      sets: sets ?? this.sets,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }
}
