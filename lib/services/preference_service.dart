import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/models/health_and_coaching_models.dart';
import 'package:ai_gym_flutter/models/routine.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/models/workout.dart';

/// Persists non-sensitive local preferences and offline draft/queue records
/// using SharedPreferences. Notifies listeners immediately on change.
class PreferenceService extends ChangeNotifier {
  PreferenceService(this._prefs);

  final SharedPreferences _prefs;

  static const String keyLanguage = 'pref_language_code';
  static const String keyGlassTheme = 'pref_glass_theme';
  static const String keyThemeMode = 'pref_theme_mode';
  static const String keyLargeText = 'pref_large_text';
  static const String keyOneHanded = 'pref_one_handed';
  static const String keyUnitSystem = 'pref_unit_system';
  static const String keyDistanceUnit = 'pref_distance_unit';
  static const String keyDefaultRestSec = 'pref_default_rest_sec';
  static const String keyAutoStartRest = 'pref_auto_start_rest';
  static const String keyWorkoutReminders = 'pref_workout_reminders';
  static const String keyPrivatePhotos = 'pref_private_photos';
  static const String keyCameraSaveConsent = 'pref_camera_save_consent';
  static const String keyAnalyticsConsent = 'pref_analytics_consent';
  static const String keyCrashConsent = 'pref_crash_consent';
  static const String keyLastSyncIso = 'pref_last_sync_iso';

  static const String keyLocalWorkouts = 'local_workouts_v1';
  static const String keyOfflineWorkoutQueue = 'offline_workout_queue_v1';
  static const String keyLocalRoutines = 'local_routines_v1';
  static const String keyLocalMeasurements = 'local_measurements_v1';
  static const String keyLocalHealthLogs = 'local_health_logs_v1';
  static const String keyLocalDetections = 'local_detections_v1';
  static const String keyLocalGoals = 'local_goals_v1';
  static const String keyGuestProfile = 'local_guest_profile_v1';

  static Future<PreferenceService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferenceService(prefs);
  }

  String get languageCode => _prefs.getString(keyLanguage) ?? 'en';

  Future<void> setLanguageCode(String code) async {
    final normalized = code.toLowerCase().startsWith('zh') ? 'zh' : 'en';
    await _prefs.setString(keyLanguage, normalized);
    notifyListeners();
  }

  bool get glassThemeEnabled => _prefs.getBool(keyGlassTheme) ?? true;

  Future<void> setGlassThemeEnabled(bool enabled) async {
    await _prefs.setBool(keyGlassTheme, enabled);
    notifyListeners();
  }

  ThemeMode get themeMode {
    final raw = _prefs.getString(keyThemeMode) ?? 'dark';
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  String get themeModeName {
    final mode = themeMode;
    if (mode == ThemeMode.light) return 'light';
    if (mode == ThemeMode.system) return 'system';
    return 'dark';
  }

  Future<void> setThemeMode(String modeName) async {
    await _prefs.setString(keyThemeMode, modeName);
    notifyListeners();
  }

  bool get largeTextEnabled => _prefs.getBool(keyLargeText) ?? false;

  Future<void> setLargeTextEnabled(bool value) async {
    await _prefs.setBool(keyLargeText, value);
    notifyListeners();
  }

  bool get oneHandedControlsEnabled => _prefs.getBool(keyOneHanded) ?? false;

  Future<void> setOneHandedControlsEnabled(bool value) async {
    await _prefs.setBool(keyOneHanded, value);
    notifyListeners();
  }

  String get unitSystem => _prefs.getString(keyUnitSystem) ?? 'metric';
  bool get isImperialWeight => unitSystem == 'imperial';

  Future<void> setUnitSystem(String system) async {
    await _prefs.setString(keyUnitSystem, system);
    notifyListeners();
  }

  String get distanceUnit => _prefs.getString(keyDistanceUnit) ?? 'km';
  bool get isMiles => distanceUnit == 'mi';

  Future<void> setDistanceUnit(String unit) async {
    await _prefs.setString(keyDistanceUnit, unit);
    notifyListeners();
  }

  int get defaultRestSeconds => _prefs.getInt(keyDefaultRestSec) ?? 90;

  Future<void> setDefaultRestSeconds(int seconds) async {
    await _prefs.setInt(keyDefaultRestSec, seconds.clamp(15, 600));
    notifyListeners();
  }

  bool get autoStartRestTimer => _prefs.getBool(keyAutoStartRest) ?? true;

  Future<void> setAutoStartRestTimer(bool value) async {
    await _prefs.setBool(keyAutoStartRest, value);
    notifyListeners();
  }

  bool get workoutRemindersEnabled =>
      _prefs.getBool(keyWorkoutReminders) ?? true;

  Future<void> setWorkoutRemindersEnabled(bool value) async {
    await _prefs.setBool(keyWorkoutReminders, value);
    notifyListeners();
  }

  bool get privateProgressPhotosEnabled =>
      _prefs.getBool(keyPrivatePhotos) ?? true;

  Future<void> setPrivateProgressPhotosEnabled(bool value) async {
    await _prefs.setBool(keyPrivatePhotos, value);
    notifyListeners();
  }

  /// Saving original camera images is disabled by default (Section 7).
  bool get cameraSaveConsentEnabled =>
      _prefs.getBool(keyCameraSaveConsent) ?? false;

  Future<void> setCameraSaveConsentEnabled(bool value) async {
    await _prefs.setBool(keyCameraSaveConsent, value);
    notifyListeners();
  }

  bool get analyticsConsentEnabled =>
      _prefs.getBool(keyAnalyticsConsent) ?? false;

  Future<void> setAnalyticsConsentEnabled(bool value) async {
    await _prefs.setBool(keyAnalyticsConsent, value);
    notifyListeners();
  }

  bool get crashReportingConsentEnabled =>
      _prefs.getBool(keyCrashConsent) ?? false;

  Future<void> setCrashReportingConsentEnabled(bool value) async {
    await _prefs.setBool(keyCrashConsent, value);
    notifyListeners();
  }

  String get lastSyncState =>
      _prefs.getString(keyLastSyncIso) ?? 'No sync recorded yet';

  Future<void> setLastSyncState(String status) async {
    await _prefs.setString(keyLastSyncIso, status);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Local / Offline storage helpers
  // ---------------------------------------------------------------------------
  UserProfile? getGuestProfile() {
    final raw = _prefs.getString(keyGuestProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGuestProfile(UserProfile profile) async {
    await _prefs.setString(keyGuestProfile, jsonEncode(profile.toJson()));
    notifyListeners();
  }

  List<WorkoutRecord> getLocalWorkouts() {
    return _decodeList(keyLocalWorkouts, WorkoutRecord.fromJson);
  }

  Future<void> saveLocalWorkouts(List<WorkoutRecord> workouts) async {
    final encoded = jsonEncode(workouts.map((w) => w.toJson()).toList());
    await _prefs.setString(keyLocalWorkouts, encoded);
    notifyListeners();
  }

  List<WorkoutRecord> getOfflineWorkoutQueue() {
    return _decodeList(keyOfflineWorkoutQueue, WorkoutRecord.fromJson);
  }

  Future<void> saveOfflineWorkoutQueue(List<WorkoutRecord> queue) async {
    final encoded = jsonEncode(queue.map((w) => w.toJson()).toList());
    await _prefs.setString(keyOfflineWorkoutQueue, encoded);
    notifyListeners();
  }

  List<WorkoutRoutine> getLocalRoutines() {
    return _decodeList(keyLocalRoutines, WorkoutRoutine.fromJson);
  }

  Future<void> saveLocalRoutines(List<WorkoutRoutine> routines) async {
    final encoded = jsonEncode(routines.map((r) => r.toJson()).toList());
    await _prefs.setString(keyLocalRoutines, encoded);
    notifyListeners();
  }

  List<BodyMeasurement> getLocalMeasurements() {
    return _decodeList(keyLocalMeasurements, BodyMeasurement.fromJson);
  }

  Future<void> saveLocalMeasurements(List<BodyMeasurement> list) async {
    final encoded = jsonEncode(list.map((m) => m.toJson()).toList());
    await _prefs.setString(keyLocalMeasurements, encoded);
    notifyListeners();
  }

  List<HealthLogRecord> getLocalHealthLogs() {
    return _decodeList(keyLocalHealthLogs, HealthLogRecord.fromJson);
  }

  Future<void> saveLocalHealthLogs(List<HealthLogRecord> list) async {
    final encoded = jsonEncode(list.map((h) => h.toJson()).toList());
    await _prefs.setString(keyLocalHealthLogs, encoded);
    notifyListeners();
  }

  List<CameraDetectionRecord> getLocalDetections() {
    return _decodeList(keyLocalDetections, CameraDetectionRecord.fromJson);
  }

  Future<void> saveLocalDetections(List<CameraDetectionRecord> list) async {
    final encoded =
        jsonEncode(list.map((d) => d.toDatabaseRow()).toList());
    await _prefs.setString(keyLocalDetections, encoded);
    notifyListeners();
  }

  List<UserGoalRecord> getLocalGoals() {
    return _decodeList(keyLocalGoals, UserGoalRecord.fromJson);
  }

  Future<void> saveLocalGoals(List<UserGoalRecord> list) async {
    final encoded = jsonEncode(list.map((g) => g.toJson()).toList());
    await _prefs.setString(keyLocalGoals, encoded);
    notifyListeners();
  }

  List<T> _decodeList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    } catch (_) {
      return <T>[];
    }
  }

  Map<String, dynamic> diagnosticsSnapshot() {
    return {
      'language': languageCode,
      'glassTheme': glassThemeEnabled,
      'themeMode': themeModeName,
      'largeText': largeTextEnabled,
      'oneHanded': oneHandedControlsEnabled,
      'unitSystem': unitSystem,
      'distanceUnit': distanceUnit,
      'defaultRestSeconds': defaultRestSeconds,
      'autoStartRestTimer': autoStartRestTimer,
      'cameraSaveConsent': cameraSaveConsentEnabled,
      'offlineQueueCount': getOfflineWorkoutQueue().length,
      'lastSyncState': lastSyncState,
    };
  }
}
