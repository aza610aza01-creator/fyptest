import 'package:flutter/foundation.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';
import 'package:ai_gym_flutter/services/notification_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Coordinates application startup, saved rest-timer recovery, and runtime environment checks.
class AppStartupController extends ChangeNotifier {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  AppStartupController({
    required this.config,
    required this.prefs,
    required this.diagnostics,
    required this.notifications,
  }) {
    _recoverPendingRestTimer();
  }

  final AppConfig config;
  final PreferenceService prefs;
  final DiagnosticsService diagnostics;
  final NotificationService notifications;

  bool _isReady = true;
  bool get isReady => _isReady;

  void _recoverPendingRestTimer() {
    final savedEndUtc = prefs.getRestTimerEndUtc();
    if (savedEndUtc != null) {
      notifications.recoverFromTimestamp(
        savedEndUtc,
        totalSeconds: prefs.defaultRestSeconds,
      );
    }
    _isReady = true;
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
