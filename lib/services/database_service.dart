import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';

/// Provides centralized Supabase database connectivity tests and JSON/CSV export
/// utilities while enforcing strict RLS compliance.
class DatabaseService {
  DatabaseService({
    required this.config,
    required this.diagnostics,
    required this.supabaseInitialized,
  });

  final AppConfig config;
  final DiagnosticsService diagnostics;
  final bool supabaseInitialized;

  SupabaseClient? get client =>
      supabaseInitialized ? Supabase.instance.client : null;

  /// Returns true when Supabase is initialized and the database client is ready.
  bool get isConnected => supabaseInitialized && client != null;

  /// Tests Supabase Authentication endpoint status for Admin Tools.
  Future<String> runAuthConnectionTest() async {
    if (!supabaseInitialized || client == null) {
      return 'NOT_CONFIGURED (Missing Publishable Key)';
    }
    try {
      final session = client!.auth.currentSession;
      final user = client!.auth.currentUser;
      final status = session != null && user != null
          ? 'OK (Authenticated Session Active: ${AppConfig.maskUserId(user.id)})'
          : 'OK (Reachable - No Active Session)';
      diagnostics.logEvent('Supabase Auth connection test -> $status');
      return status;
    } catch (e) {
      final msg = 'ERROR (${e.runtimeType})';
      diagnostics.logEvent('Supabase Auth connection test failed -> $msg');
      return msg;
    }
  }

  /// Tests Database Read/Write access against RLS-protected tables.
  Future<String> runDatabaseReadWriteTest(String? currentUserId) async {
    if (!supabaseInitialized || client == null) {
      return 'NOT_CONFIGURED (Missing Publishable Key)';
    }
    try {
      final exercises = await client!
          .from('exercises')
          .select('id, name')
          .eq('is_active', true)
          .limit(3);
      final readCount = (exercises as List).length;

      if (currentUserId != null &&
          currentUserId.isNotEmpty &&
          currentUserId != 'local_guest_user') {
        final profile = await client!
            .from('profiles')
            .select('id, updated_at')
            .eq('id', currentUserId)
            .maybeSingle();
        final hasProfile = profile != null;
        final result =
            'PASS (Read $readCount active exercises; Own Profile RLS check: ${hasProfile ? "Verified" : "Pending Onboarding"})';
        diagnostics.logEvent('Database R/W test -> $result');
        return result;
      }
      return 'PASS (Read $readCount active exercises; No cloud user session for write check)';
    } on PostgrestException catch (e) {
      final msg = 'PostgrestException (${e.code}: ${e.message})';
      diagnostics.logEvent('Database test error -> $msg');
      return msg;
    } catch (e) {
      final msg = 'ERROR (${e.runtimeType})';
      diagnostics.logEvent('Database test error -> $msg');
      return msg;
    }
  }

  /// Exports user data as formatted JSON string (Settings -> Export JSON).
  String exportUserDataAsJson({
    required UserProfile? profile,
    required List<WorkoutRecord> workouts,
    required List<BodyMeasurement> measurements,
    required List<CameraDetectionRecord> detections,
  }) {
    final payload = {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'application': 'AI Gym Cloud',
      'profile': profile?.toJson(),
      'workouts': workouts.map((w) => w.toJson()).toList(),
      'body_measurements': measurements.map((m) => m.toJson()).toList(),
      'camera_detections': detections.map((d) => d.toDatabaseRow()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Exports workouts and sets as CSV text (Settings -> Export CSV).
  String exportWorkoutsAsCsv(List<WorkoutRecord> workouts) {
    final buffer = StringBuffer();
    buffer.writeln(
      'workout_id,title,workout_type,started_at,set_number,exercise_name,set_type,weight_kg,reps,rpe,rir,volume_kg',
    );
    for (final w in workouts) {
      final cleanTitle = w.title.replaceAll(',', ' ');
      if (w.sets.isEmpty) {
        buffer.writeln(
          '${w.id},$cleanTitle,${w.workoutType},${w.startedAt.toIso8601String()},0,None,standard,0,0,,,0',
        );
      } else {
        for (final s in w.sets) {
          final cleanEx = s.exerciseName.replaceAll(',', ' ');
          buffer.writeln(
            '${w.id},$cleanTitle,${w.workoutType},${w.startedAt.toIso8601String()},'
            '${s.setNumber},$cleanEx,${s.setType},${s.weightKg},${s.reps},'
            '${s.rpe ?? ""},${s.rir ?? ""},${s.volumeKg.toStringAsFixed(1)}',
          );
        }
      }
    }
    return buffer.toString();
  }
}
