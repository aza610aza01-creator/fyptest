/// Model for `public.profiles` table.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.age,
    this.heightCm,
    this.weightKg,
    this.sex = 'prefer_not_to_say',
    this.goal = 'general_health',
    this.experienceLevel = 'beginner',
    this.injuryFlags = const <String>[],
    this.equipmentAccess = 'full_gym',
    this.unitSystem = 'metric',
    this.language = 'en',
    this.timezone = 'Asia/Hong_Kong',
    this.subscriptionPlan = 'free',
    this.onboardingCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String displayName;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final String sex;
  final String goal;
  final String experienceLevel;
  final List<String> injuryFlags;
  final String equipmentAccess;
  final String unitSystem;
  final String language;
  final String timezone;
  final String subscriptionPlan;
  final bool onboardingCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isIncomplete =>
      !onboardingCompleted ||
      displayName.trim().isEmpty ||
      age == null ||
      heightCm == null ||
      weightKg == null;

  bool get isImperial => unitSystem == 'imperial';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawFlags = json['injury_flags'];
    final flags = rawFlags is List
        ? rawFlags.map((e) => e.toString()).toList()
        : <String>[];

    return UserProfile(
      id: (json['id'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      age: json['age'] is num ? (json['age'] as num).toInt() : null,
      heightCm:
          json['height_cm'] is num ? (json['height_cm'] as num).toDouble() : null,
      weightKg:
          json['weight_kg'] is num ? (json['weight_kg'] as num).toDouble() : null,
      sex: (json['sex'] ?? 'prefer_not_to_say').toString(),
      goal: (json['goal'] ?? 'general_health').toString(),
      experienceLevel: (json['experience_level'] ?? 'beginner').toString(),
      injuryFlags: flags,
      equipmentAccess: (json['equipment_access'] ?? 'full_gym').toString(),
      unitSystem: (json['unit_system'] ?? 'metric').toString(),
      language: (json['language'] ?? 'en').toString(),
      timezone: (json['timezone'] ?? 'Asia/Hong_Kong').toString(),
      subscriptionPlan: (json['subscription_plan'] ?? 'free').toString(),
      onboardingCompleted: json['onboarding_completed'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'age': age,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'sex': sex,
      'goal': goal,
      'experience_level': experienceLevel,
      'injury_flags': injuryFlags,
      'equipment_access': equipmentAccess,
      'unit_system': unitSystem,
      'language': language,
      'timezone': timezone,
      'subscription_plan': subscriptionPlan,
      'onboarding_completed': onboardingCompleted,
    };
  }

  UserProfile copyWith({
    String? id,
    String? displayName,
    int? age,
    double? heightCm,
    double? weightKg,
    String? sex,
    String? goal,
    String? experienceLevel,
    List<String>? injuryFlags,
    String? equipmentAccess,
    String? unitSystem,
    String? language,
    String? timezone,
    String? subscriptionPlan,
    bool? onboardingCompleted,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      sex: sex ?? this.sex,
      goal: goal ?? this.goal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      injuryFlags: injuryFlags ?? this.injuryFlags,
      equipmentAccess: equipmentAccess ?? this.equipmentAccess,
      unitSystem: unitSystem ?? this.unitSystem,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
