import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_gym_flutter/app/app.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/services/auth_service.dart';
import 'package:ai_gym_flutter/services/camera_detection_service.dart';
import 'package:ai_gym_flutter/services/database_service.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';
import 'package:ai_gym_flutter/services/notification_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final prefs = await PreferenceService.create();
  final diagnostics = DiagnosticsService();
  final notifications = NotificationService();

  bool supabaseReady = false;
  if (config.isConfigured) {
    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        anonKey: config.supabasePublishableKey,
      );
      supabaseReady = true;
      diagnostics.logEvent('Supabase initialized for ${config.supabaseUrl}');
    } catch (e) {
      diagnostics.logEvent('Supabase initialization failed: ${e.runtimeType}');
    }
  } else {
    diagnostics.logEvent(
      'Missing SUPABASE_PUBLISHABLE_KEY; showing configuration guidance.',
    );
  }

  final authService = AuthService(
    config: config,
    diagnostics: diagnostics,
    supabaseInitialized: supabaseReady,
  );
  final dbService = DatabaseService(
    config: config,
    diagnostics: diagnostics,
    supabaseInitialized: supabaseReady,
  );
  final cameraService = CameraDetectionService(diagnostics: diagnostics);

  runApp(
    AiGymCloudApp(
      config: config,
      prefs: prefs,
      diagnostics: diagnostics,
      notifications: notifications,
      authService: authService,
      dbService: dbService,
      cameraService: cameraService,
    ),
  );
}
