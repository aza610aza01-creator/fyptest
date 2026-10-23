/// Model for `public.exercises` table.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.secondaryMuscles = const <String>[],
    required this.equipment,
    required this.instructions,
    this.cues = const <String>[],
    this.commonMistakes = const <String>[],
    this.demoUrl,
    this.illustrationUrl,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String muscleGroup;
  final List<String> secondaryMuscles;
  final String equipment;
  final String instructions;
  final List<String> cues;
  final List<String> commonMistakes;
  final String? demoUrl;
  final String? illustrationUrl;
  final bool isActive;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    List<String> toList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return <String>[];
    }

    return Exercise(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      muscleGroup: (json['muscle_group'] ?? 'General').toString(),
      secondaryMuscles: toList(json['secondary_muscles']),
      equipment: (json['equipment'] ?? 'Bodyweight').toString(),
      instructions: (json['instructions'] ?? '').toString(),
      cues: toList(json['cues']),
      commonMistakes: toList(json['common_mistakes']),
      demoUrl: json['demo_url']?.toString(),
      illustrationUrl: json['illustration_url']?.toString(),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'muscle_group': muscleGroup,
      'secondary_muscles': secondaryMuscles,
      'equipment': equipment,
      'instructions': instructions,
      'cues': cues,
      'common_mistakes': commonMistakes,
      'demo_url': demoUrl,
      'illustration_url': illustrationUrl,
      'is_active': isActive,
    };
  }

  /// Built-in default seed exercises matching `supabase/seed.sql`.
  static List<Exercise> defaultSeedExercises() {
    return const [
      Exercise(
        id: 'seed-squat',
        name: 'Squat',
        muscleGroup: 'Legs',
        secondaryMuscles: ['Glutes', 'Core', 'Lower Back'],
        equipment: 'Barbell',
        instructions:
            'Stand with feet shoulder-width apart, brace your core, hinge hips back and bend knees until thighs are parallel, then drive up.',
        cues: [
          'Chest proud and neutral spine',
          'Knees track over toes',
          'Brace 360 degrees around core',
        ],
        commonMistakes: [
          'Knees caving inward (valgus)',
          'Rounding lower back',
          'Lifting heels off floor',
        ],
      ),
      Exercise(
        id: 'seed-pushup',
        name: 'Push-up',
        muscleGroup: 'Chest',
        secondaryMuscles: ['Triceps', 'Anterior Deltoids', 'Core'],
        equipment: 'Bodyweight',
        instructions:
            'Start in a high plank, lower chest cleanly toward the floor with elbows at 45 degrees, and press back to full lockout.',
        cues: ['Rigid plank line', 'Elbows at 45 degrees', 'Full lockout at top'],
        commonMistakes: ['Sagging hips', 'Flaring elbows to 90 degrees'],
      ),
      Exercise(
        id: 'seed-deadlift',
        name: 'Deadlift',
        muscleGroup: 'Back',
        secondaryMuscles: ['Hamstrings', 'Glutes', 'Forearms', 'Core'],
        equipment: 'Barbell',
        instructions:
            'Stand with mid-foot under the bar, grip outside knees, brace lats and core, and drive the floor away to lockout.',
        cues: ['Keep bar close to shins', 'Engage lats', 'Hinge hips on descent'],
        commonMistakes: ['Rounding lumbar spine', 'Jerking the bar'],
      ),
      Exercise(
        id: 'seed-bench-press',
        name: 'Bench Press',
        muscleGroup: 'Chest',
        secondaryMuscles: ['Triceps', 'Anterior Deltoids'],
        equipment: 'Barbell',
        instructions:
            'Lie flat on bench, retract shoulder blades, lower bar with control to lower chest, and press smoothly upward.',
        cues: ['Retract scapula', 'Drive feet into floor', 'Stack wrists'],
        commonMistakes: ['Bouncing bar off chest', 'Lifting hips off bench'],
      ),
      Exercise(
        id: 'seed-shoulder-press',
        name: 'Shoulder Press',
        muscleGroup: 'Shoulders',
        secondaryMuscles: ['Triceps', 'Upper Chest', 'Core'],
        equipment: 'Dumbbell',
        instructions:
            'Press dumbbells overhead from shoulder height while bracing core and glutes, then lower under control.',
        cues: ['Squeeze glutes and ribs down', 'Press vertically'],
        commonMistakes: ['Excessive lumbar arch', 'Shortening range of motion'],
      ),
      Exercise(
        id: 'seed-bicep-curl',
        name: 'Bicep Curl',
        muscleGroup: 'Arms',
        secondaryMuscles: ['Forearms', 'Brachialis'],
        equipment: 'Dumbbell',
        instructions:
            'Keep elbows pinned to your sides, curl dumbbells toward shoulders with full supination, and lower slowly.',
        cues: ['Elbows stay stationary', 'Control 2-second eccentric'],
        commonMistakes: ['Swinging torso for momentum', 'Moving elbows forward'],
      ),
      Exercise(
        id: 'seed-plank',
        name: 'Plank',
        muscleGroup: 'Core',
        secondaryMuscles: ['Shoulders', 'Glutes'],
        equipment: 'Bodyweight',
        instructions:
            'Hold a straight body line supported on forearms and toes while breathing steadily.',
        cues: ['Push forearms into floor', 'Posterior pelvic tilt'],
        commonMistakes: ['Dropping hips', 'Holding breath'],
      ),
      Exercise(
        id: 'seed-running',
        name: 'Running',
        muscleGroup: 'Cardio',
        secondaryMuscles: ['Quadriceps', 'Calves', 'Hamstrings'],
        equipment: 'Treadmill / Outdoor',
        instructions:
            'Run with upright posture, relaxed shoulders, and a light rhythmic cadence.',
        cues: ['Relax shoulders', 'Land softly under hips'],
        commonMistakes: ['Overstriding with heavy heel strike'],
      ),
      Exercise(
        id: 'seed-cycling',
        name: 'Cycling',
        muscleGroup: 'Cardio',
        secondaryMuscles: ['Quadriceps', 'Glutes', 'Calves'],
        equipment: 'Stationary Bike / Road',
        instructions:
            'Pedal smoothly through 360-degree circles with proper saddle height and neutral spine.',
        cues: ['Smooth pedal stroke', 'Maintain target cadence'],
        commonMistakes: ['Saddle too low', 'Rocking hips'],
      ),
    ];
  }
}
