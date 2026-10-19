/// Model for `public.body_measurements`.
class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.userId,
    required this.recordedAt,
    this.weightKg,
    this.bodyFatPercent,
    this.chestCm,
    this.waistCm,
    this.armsCm,
    this.thighsCm,
    this.photoPath,
  });

  final String id;
  final String userId;
  final DateTime recordedAt;
  final double? weightKg;
  final double? bodyFatPercent;
  final double? chestCm;
  final double? waistCm;
  final double? armsCm;
  final double? thighsCm;
  final String? photoPath;

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) => v is num ? v.toDouble() : null;
    return BodyMeasurement(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      recordedAt: json['recorded_at'] != null
          ? (DateTime.tryParse(json['recorded_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      weightKg: toDouble(json['weight_kg']),
      bodyFatPercent: toDouble(json['body_fat_percent']),
      chestCm: toDouble(json['chest_cm']),
      waistCm: toDouble(json['waist_cm']),
      armsCm: toDouble(json['arms_cm']),
      thighsCm: toDouble(json['thighs_cm']),
      photoPath: json['photo_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'weight_kg': weightKg,
      'body_fat_percent': bodyFatPercent,
      'chest_cm': chestCm,
      'waist_cm': waistCm,
      'arms_cm': armsCm,
      'thighs_cm': thighsCm,
      'photo_path': photoPath,
    };
  }
}
