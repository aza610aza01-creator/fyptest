import 'package:ai_gym_flutter/models/exercise.dart';
import 'package:ai_gym_flutter/services/database_service.dart';

/// Repository for `public.exercises` with built-in seed fallback when offline.
class ExerciseRepository {
  ExerciseRepository({required this.db});

  final DatabaseService db;

  Future<List<Exercise>> fetchExercises({required bool isGuest}) async {
    final seedList = Exercise.defaultSeedExercises();
    if (isGuest || db.client == null) {
      return seedList;
    }

    try {
      final rows = await db.client!
          .from('exercises')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);

      final parsed = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Exercise.fromJson)
          .toList();

      return parsed.isNotEmpty ? parsed : seedList;
    } catch (e) {
      db.diagnostics.logEvent('Exercise fetch fallback to local seed (${e.runtimeType})');
      return seedList;
    }
  }
}
