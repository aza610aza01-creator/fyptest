/// Supporting models for Cardio Logs, Daily Health Logs, Goals, Badges,
/// Integrations, Social Feed/Challenges, Bookings, and Subscription Plans.
class CardioLogRecord {
  const CardioLogRecord({
    required this.id,
    required this.userId,
    this.workoutId,
    required this.cardioType,
    required this.durationSeconds,
    required this.distanceKm,
    required this.averagePace,
    this.averageHeartRate,
    required this.caloriesEstimated,
    this.intervals = const <Map<String, dynamic>>[],
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? workoutId;
  final String cardioType;
  final int durationSeconds;
  final double distanceKm;
  final String averagePace;
  final int? averageHeartRate;
  final int caloriesEstimated;
  final List<Map<String, dynamic>> intervals;
  final DateTime createdAt;

  factory CardioLogRecord.fromJson(Map<String, dynamic> json) {
    final rawIntervals = json['intervals'];
    final parsedIntervals = rawIntervals is List
        ? rawIntervals.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    return CardioLogRecord(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      workoutId: json['workout_id']?.toString(),
      cardioType: (json['cardio_type'] ?? 'Running').toString(),
      durationSeconds: json['duration_seconds'] is num
          ? (json['duration_seconds'] as num).toInt()
          : 600,
      distanceKm: json['distance_km'] is num
          ? (json['distance_km'] as num).toDouble()
          : 0.0,
      averagePace: (json['average_pace'] ?? '6:00 /km').toString(),
      averageHeartRate: json['average_heart_rate'] is num
          ? (json['average_heart_rate'] as num).toInt()
          : null,
      caloriesEstimated: json['calories_estimated'] is num
          ? (json['calories_estimated'] as num).toInt()
          : 0,
      intervals: parsedIntervals,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'workout_id': workoutId,
      'cardio_type': cardioType,
      'duration_seconds': durationSeconds,
      'distance_km': distanceKm,
      'average_pace': averagePace,
      'average_heart_rate': averageHeartRate,
      'calories_estimated': caloriesEstimated,
      'intervals': intervals,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

class HealthLogRecord {
  const HealthLogRecord({
    required this.id,
    required this.userId,
    required this.recordedDate,
    this.waterMl = 0,
    this.sleepHours = 0,
    this.steps = 0,
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.restingHeartRate,
  });

  final String id;
  final String userId;
  final String recordedDate;
  final int waterMl;
  final double sleepHours;
  final int steps;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final int? restingHeartRate;

  factory HealthLogRecord.fromJson(Map<String, dynamic> json) {
    return HealthLogRecord(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      recordedDate: (json['recorded_date'] ?? '').toString(),
      waterMl: json['water_ml'] is num ? (json['water_ml'] as num).toInt() : 0,
      sleepHours: json['sleep_hours'] is num
          ? (json['sleep_hours'] as num).toDouble()
          : 0.0,
      steps: json['steps'] is num ? (json['steps'] as num).toInt() : 0,
      calories: json['calories'] is num ? (json['calories'] as num).toInt() : 0,
      proteinG: json['protein_g'] is num
          ? (json['protein_g'] as num).toDouble()
          : 0.0,
      carbsG:
          json['carbs_g'] is num ? (json['carbs_g'] as num).toDouble() : 0.0,
      fatG: json['fat_g'] is num ? (json['fat_g'] as num).toDouble() : 0.0,
      restingHeartRate: json['resting_heart_rate'] is num
          ? (json['resting_heart_rate'] as num).toInt()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'recorded_date': recordedDate,
      'water_ml': waterMl,
      'sleep_hours': sleepHours,
      'steps': steps,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'resting_heart_rate': restingHeartRate,
    };
  }
}

class UserGoalRecord {
  const UserGoalRecord({
    required this.id,
    required this.userId,
    required this.goalType,
    required this.targetValue,
    required this.currentValue,
    this.targetDate,
    this.status = 'active',
  });

  final String id;
  final String userId;
  final String goalType;
  final double targetValue;
  final double currentValue;
  final DateTime? targetDate;
  final String status;

  /// Human-readable goal title (backward-compatible getter used by DashboardScreen).
  String get title => goalType;

  /// Extracted unit suffix if present in `goalType` (e.g. `kg` from `Weekly Volume (kg)`).
  String get unit {
    final openIdx = goalType.indexOf('(');
    final closeIdx = goalType.indexOf(')');
    if (openIdx != -1 && closeIdx > openIdx + 1) {
      return goalType.substring(openIdx + 1, closeIdx).trim();
    }
    return '';
  }

  double get progressRatio {
    if (targetValue <= 0) return 0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  factory UserGoalRecord.fromJson(Map<String, dynamic> json) {
    return UserGoalRecord(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      goalType: (json['goal_type'] ?? 'Weekly Volume (kg)').toString(),
      targetValue: json['target_value'] is num
          ? (json['target_value'] as num).toDouble()
          : 1000,
      currentValue: json['current_value'] is num
          ? (json['current_value'] as num).toDouble()
          : 0,
      targetDate: json['target_date'] != null
          ? DateTime.tryParse(json['target_date'].toString())
          : null,
      status: (json['status'] ?? 'active').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'goal_type': goalType,
      'target_value': targetValue,
      'current_value': currentValue,
      'target_date': targetDate?.toIso8601String().split('T').first,
      'status': status,
    };
  }
}

class HealthIntegrationDescriptor {
  const HealthIntegrationDescriptor({
    required this.id,
    required this.name,
    required this.platformNoteEn,
    required this.platformNoteZh,
    this.sdkConfigured = false,
  });

  final String id;
  final String name;
  final String platformNoteEn;
  final String platformNoteZh;
  final bool sdkConfigured;
}
