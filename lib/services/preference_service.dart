import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/models/health_and_coaching_models.dart';
import 'package:ai_gym_flutter/models/routine.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/models/workout_set.dart';

/// Immutable snapshot of an autosaved in-progress workout session for crash/lifecycle recovery.
@immutable
class WorkoutDraftData {
  const WorkoutDraftData({
    required this.userId,
    required this.title,
    required this.selectedExerciseId,
    required this.selectedSetType,
    required this.weightValue,
    required this.repsValue,
    required this.rpeValue,
    required this.rirValue,
    required this.sessionNotes,
    required this.startedAtUtc,
    required this.sets,
    this.restTimerEndUtc,
  });

  final String userId;
  final String title;
  final String selectedExerciseId;
  final String selectedSetType;
  final double weightValue;
  final int repsValue;
  final double rpeValue;
  final int rirValue;
  final String sessionNotes;
  final DateTime startedAtUtc;
  final List<WorkoutSetRecord> sets;
  final DateTime? restTimerEndUtc;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'title': title,
        'selected_exercise_id': selectedExerciseId,
        'selected_set_type': selectedSetType,
        'weight_value': weightValue,
        'reps_value': repsValue,
        'rpe_value': rpeValue,
        'rir_value': rirValue,
        'session_notes': sessionNotes,
        'started_at_utc': startedAtUtc.toUtc().toIso8601String(),
        'sets': sets.map((s) => s.toJson()).toList(),
        'rest_timer_end_utc': restTimerEndUtc?.toUtc().toIso8601String(),
      };

  factory WorkoutDraftData.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'];
    final parsedSets = <WorkoutSetRecord>[];
    if (rawSets is List) {
      for (final item in rawSets.whereType<Map<String, dynamic>>()) {
        parsedSets.add(WorkoutSetRecord.fromJson(item));
      }
    }
    return WorkoutDraftData(
      userId: (json['user_id'] ?? '').toString(),
      title: (json['title'] ?? 'Strength & Hypertrophy Session').toString(),
      selectedExerciseId: (json['selected_exercise_id'] ?? 'seed-squat').toString(),
      selectedSetType: (json['selected_set_type'] ?? 'standard').toString(),
      weightValue: (json['weight_value'] is num)
          ? (json['weight_value'] as num).toDouble()
          : 60.0,
      repsValue: (json['reps_value'] is num)
          ? (json['reps_value'] as num).toInt()
          : 8,
      rpeValue: (json['rpe_value'] is num)
          ? (json['rpe_value'] as num).toDouble()
          : 8.0,
      rirValue: (json['rir_value'] is num)
          ? (json['rir_value'] as num).toInt()
          : 2,
      sessionNotes: (json['session_notes'] ?? '').toString(),
      startedAtUtc: DateTime.tryParse((json['started_at_utc'] ?? '').toString())
              ?.toUtc() ??
          DateTime.now().toUtc(),
      sets: parsedSets,
      restTimerEndUtc: json['rest_timer_end_utc'] != null
          ? DateTime.tryParse(json['rest_timer_end_utc'].toString())?.toUtc()
          : null,
    );
  }
}

/// Persists non-sensitive local preferences, user-partitioned offline cache,
/// recoverable workout drafts, and offline pending queues using SharedPreferences.
class PreferenceService extends ChangeNotifier {
  PreferenceService(this._prefs);

  final SharedPreferences _prefs;

  static const String keyLanguage = 'pref_language_code';
  static const String keyGlassTheme = 'pref_glass_theme';
  static const String keyIosPreviewMode = 'pref_ios_preview_mode';
  static const String keyDeveloperMode = 'pref_developer_mode';
  static const String keyThemeMode = 'pref_theme_mode';
  static const String keyLargeText = 'pref_large_text';
  static const String keyReducedMotion = 'pref_reduced_motion';
  static const String keyHapticsEnabled = 'pref_haptics_enabled';
  static const String keyWifiOnlySync = 'pref_wifi_only_sync';
  static const String keyOneHanded = 'pref_one_handed';
  static const String keyUnitSystem = 'pref_unit_system';
  static const String keyDistanceUnit = 'pref_distance_unit';
  static const String keyDefaultRestSec = 'pref_default_rest_sec';
  static const String keyAutoStartRest = 'pref_auto_start_rest';
  static const String keyRestTimerEndUtc = 'pref_rest_timer_end_utc';
  static const String keyWorkoutReminders = 'pref_workout_reminders';
  static const String keyPrivatePhotos = 'pref_private_photos';
  static const String keyCameraSaveConsent = 'pref_camera_save_consent';
  static const String keyAnalyticsConsent = 'pref_analytics_consent';
  static const String keyCrashConsent = 'pref_crash_consent';
  static const String keyLastSyncIso = 'pref_last_sync_iso';
  static const String keyDashboardCards = 'pref_dashboard_cards_v1';
  static const String keyActiveWorkoutDraft = 'pref_active_workout_draft_v1';
  static const String keyPendingGuestMigration = 'pref_pending_guest_migration';

  static const String keyLocalWorkouts = 'local_workouts_v1';
  static const String keyOfflineWorkoutQueue = 'offline_workout_queue_v1';
  static const String keyLocalRoutines = 'local_routines_v1';
  static const String keyLocalMeasurements = 'local_measurements_v1';
  static const String keyLocalHealthLogs = 'local_health_logs_v1';
  static const String keyLocalDetections = 'local_detections_v1';
  static const String keyLocalGoals = 'local_goals_v1';
  static const String keyGuestProfile = 'local_guest_profile_v1';

  static const List<String> defaultDashboardCards = <String>[
    'realtime_camera_showcase',
    'today_workout',
    'weekly_progress',
    'active_goal',
    'workout_streak',
    'personal_records',
    'weight_trend',
    'sync_status',
    'rest_day_suggestion',
  ];

  static Future<PreferenceService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferenceService(prefs);
  }

  String scopedKey(String baseKey, [String? userId]) {
    if (userId == null || userId.isEmpty || userId == 'guest-local-user') {
      return baseKey;
    }
    return '${baseKey}_$userId';
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

  /// Developer Mode controls access to simulated iOS/Android preview chrome and
  /// low-level camera/FPS diagnostics for non-admin sessions.
  bool get developerModeEnabled => _prefs.getBool(keyDeveloperMode) ?? false;

  Future<void> setDeveloperModeEnabled(bool enabled) async {
    await _prefs.setBool(keyDeveloperMode, enabled);
    if (!enabled) {
      await _prefs.setBool(keyIosPreviewMode, false);
    }
    notifyListeners();
  }

  /// iOS/Android preview shell is hidden from normal users by default unless
  /// Developer Mode is active or explicitly enabled.
  bool get iosPreviewModeEnabled =>
      _prefs.getBool(keyIosPreviewMode) ?? false;

  Future<void> setIosPreviewModeEnabled(bool enabled) async {
    await _prefs.setBool(keyIosPreviewMode, enabled);
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

  bool get reducedMotionEnabled => _prefs.getBool(keyReducedMotion) ?? false;

  Future<void> setReducedMotionEnabled(bool value) async {
    await _prefs.setBool(keyReducedMotion, value);
    notifyListeners();
  }

  bool get hapticsEnabled => _prefs.getBool(keyHapticsEnabled) ?? true;

  Future<void> setHapticsEnabled(bool value) async {
    await _prefs.setBool(keyHapticsEnabled, value);
    notifyListeners();
  }

  bool get wifiOnlySyncEnabled => _prefs.getBool(keyWifiOnlySync) ?? false;

  Future<void> setWifiOnlySyncEnabled(bool value) async {
    await _prefs.setBool(keyWifiOnlySync, value);
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

  DateTime? getRestTimerEndUtc() {
    final raw = _prefs.getString(keyRestTimerEndUtc);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> setRestTimerEndUtc(DateTime? targetUtc) async {
    if (targetUtc == null) {
      await _prefs.remove(keyRestTimerEndUtc);
    } else {
      await _prefs.setString(
        keyRestTimerEndUtc,
        targetUtc.toUtc().toIso8601String(),
      );
    }
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

  /// Saving original camera images is disabled by default (Section 7 & 13).
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

  List<String> get visibleDashboardCards {
    final stored = _prefs.getStringList(keyDashboardCards);
    if (stored == null || stored.isEmpty) return defaultDashboardCards;
    return stored;
  }

  bool isDashboardCardVisible(String cardKey) =>
      visibleDashboardCards.contains(cardKey);

  Future<void> toggleDashboardCard(String cardKey, bool visible) async {
    final current = List<String>.from(visibleDashboardCards);
    if (visible && !current.contains(cardKey)) {
      current.add(cardKey);
    } else if (!visible) {
      current.remove(cardKey);
    }
    await _prefs.setStringList(keyDashboardCards, current);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Active Workout Draft Autosave & Recovery
  // ---------------------------------------------------------------------------
  WorkoutDraftData? getWorkoutDraft([String? userId]) {
    final key = scopedKey(keyActiveWorkoutDraft, userId);
    final raw = _prefs.getString(key) ?? _prefs.getString(keyActiveWorkoutDraft);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return WorkoutDraftData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWorkoutDraft(WorkoutDraftData draft) async {
    final encoded = jsonEncode(draft.toJson());
    await _prefs.setString(keyActiveWorkoutDraft, encoded);
    await _prefs.setString(
      scopedKey(keyActiveWorkoutDraft, draft.userId),
      encoded,
    );
  }

  Future<void> clearWorkoutDraft([String? userId]) async {
    await _prefs.remove(keyActiveWorkoutDraft);
    if (userId != null && userId.isNotEmpty) {
      await _prefs.remove(scopedKey(keyActiveWorkoutDraft, userId));
    }
  }

  // ---------------------------------------------------------------------------
  // Guest Upgrade & Local / Offline storage helpers
  // ---------------------------------------------------------------------------
  bool get pendingGuestMigration =>
      _prefs.getBool(keyPendingGuestMigration) ?? false;

  Future<void> setPendingGuestMigration(bool pending) async {
    await _prefs.setBool(keyPendingGuestMigration, pending);
    notifyListeners();
  }

  bool hasGuestDataToMigrate() {
    return getLocalWorkouts().isNotEmpty ||
        getLocalRoutines().isNotEmpty ||
        getLocalMeasurements().isNotEmpty ||
        getLocalHealthLogs().isNotEmpty ||
        getLocalDetections().isNotEmpty ||
        getLocalGoals().isNotEmpty;
  }

  Future<void> clearGuestDataAfterMigration() async {
    await _prefs.remove(keyGuestProfile);
    await _prefs.remove(keyLocalWorkouts);
    await _prefs.remove(keyLocalRoutines);
    await _prefs.remove(keyLocalMeasurements);
    await _prefs.remove(keyLocalHealthLogs);
    await _prefs.remove(keyLocalDetections);
    await _prefs.remove(keyLocalGoals);
    await _prefs.setBool(keyPendingGuestMigration, false);
    notifyListeners();
  }

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

  List<WorkoutRecord> getLocalWorkouts([String? userId]) {
    final scoped = _decodeList(
      scopedKey(keyLocalWorkouts, userId),
      WorkoutRecord.fromJson,
    );
    if (scoped.isNotEmpty) return scoped;
    return _decodeList(keyLocalWorkouts, WorkoutRecord.fromJson);
  }

  Future<void> saveLocalWorkouts(
    List<WorkoutRecord> workouts, [
    String? userId,
  ]) async {
    final encoded = jsonEncode(workouts.map((w) => w.toJson()).toList());
    await _prefs.setString(scopedKey(keyLocalWorkouts, userId), encoded);
    await _prefs.setString(keyLocalWorkouts, encoded);
    notifyListeners();
  }

  List<WorkoutRecord> getOfflineWorkoutQueue([String? userId]) {
    final scoped = _decodeList(
      scopedKey(keyOfflineWorkoutQueue, userId),
      WorkoutRecord.fromJson,
    );
    if (scoped.isNotEmpty) return scoped;
    return _decodeList(keyOfflineWorkoutQueue, WorkoutRecord.fromJson);
  }

  Future<void> saveOfflineWorkoutQueue(
    List<WorkoutRecord> queue, [
    String? userId,
  ]) async {
    final encoded = jsonEncode(queue.map((w) => w.toJson()).toList());
    await _prefs.setString(scopedKey(keyOfflineWorkoutQueue, userId), encoded);
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
      'developerMode': developerModeEnabled,
      'iosPreviewMode': iosPreviewModeEnabled,
      'themeMode': themeModeName,
      'largeText': largeTextEnabled,
      'reducedMotion': reducedMotionEnabled,
      'hapticsEnabled': hapticsEnabled,
      'wifiOnlySync': wifiOnlySyncEnabled,
      'oneHanded': oneHandedControlsEnabled,
      'unitSystem': unitSystem,
      'distanceUnit': distanceUnit,
      'defaultRestSeconds': defaultRestSeconds,
      'autoStartRestTimer': autoStartRestTimer,
      'cameraSaveConsent': cameraSaveConsentEnabled,
      'offlineQueueCount': getOfflineWorkoutQueue().length,
      'hasActiveDraft': getWorkoutDraft() != null,
      'lastSyncState': lastSyncState,
    };
  }
}
