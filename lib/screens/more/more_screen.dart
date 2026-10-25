import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/controllers/navigation_controller.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/models/exercise.dart';
import 'package:ai_gym_flutter/models/health_and_coaching_models.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/screens/body_health/body_health_screen.dart';
import 'package:ai_gym_flutter/screens/diagnostics/diagnostics_screen.dart';
import 'package:ai_gym_flutter/screens/exercise_library/exercise_library_screen.dart';
import 'package:ai_gym_flutter/screens/settings/settings_screen.dart';
import 'package:ai_gym_flutter/services/auth_service.dart';
import 'package:ai_gym_flutter/services/database_service.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Secondary destination hub (`More` tab) housing Exercise Library, Body & Health,
/// Settings, and access-controlled Admin Diagnostics so mobile bottom navigation
/// stays clean and ergonomic with 5 primary tabs.
class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.navigationController,
    required this.config,
    required this.user,
    required this.profile,
    required this.exercises,
    required this.workouts,
    required this.measurements,
    required this.healthLogs,
    required this.detections,
    required this.prefs,
    required this.authService,
    required this.dbService,
    required this.diagnostics,
    required this.onSaveMeasurement,
    required this.onSaveHealthLog,
    required this.onUpgradeGuest,
  });

  final NavigationController navigationController;
  final AppConfig config;
  final AppUser user;
  final UserProfile? profile;
  final List<Exercise> exercises;
  final List<WorkoutRecord> workouts;
  final List<BodyMeasurement> measurements;
  final List<HealthLogRecord> healthLogs;
  final List<CameraDetectionRecord> detections;
  final PreferenceService prefs;
  final AuthService authService;
  final DatabaseService dbService;
  final DiagnosticsService diagnostics;
  final Future<void> Function(BodyMeasurement) onSaveMeasurement;
  final Future<void> Function(HealthLogRecord) onSaveHealthLog;
  final VoidCallback onUpgradeGuest;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: navigationController,
      builder: (context, _) {
        final strings = AppStrings.of(context, prefs.languageCode);
        final isZh = strings.isZh;
        final sub = navigationController.moreSubDestination;

        if (sub != MoreSubDestination.hub) {
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: navigationController.backToMoreHub,
                        icon: const Icon(Icons.arrow_back_ios_new, size: 15),
                        label: Text(isZh ? '返回更多功能' : 'Back to More'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _subTitle(sub, strings, isZh),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _buildSubScreen(sub),
              ),
            ],
          );
        }

        final glass = prefs.glassThemeEnabled;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            GlassPanel(
              glassEnabled: glass,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isZh ? '更多功能與個人設定' : 'More Modules & Athlete Settings',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isZh
                        ? '瀏覽動作庫、身體指標與營養紀錄、主題與語言設定。'
                        : 'Access the Exercise Library, Body & Health tracker, and App Settings.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            GlassPanel(
              glassEnabled: glass,
              child: Column(
                children: [
                  ListTile(
                    key: const Key('more_exercise_library_tile'),
                    leading: const Icon(Icons.menu_book_outlined, color: Color(0xFF0A84FF)),
                    title: Text(
                      strings.tr('nav_library'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      isZh
                          ? '${exercises.length} 項標準訓練動作、肌群篩選與教練提示'
                          : '${exercises.length} exercises with muscle filters & coaching cues',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => navigationController.openMoreDestination(
                      MoreSubDestination.exerciseLibrary,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('more_body_health_tile'),
                    leading: const Icon(Icons.monitor_heart_outlined, color: Color(0xFF30D158)),
                    title: Text(
                      strings.tr('nav_health'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      isZh
                          ? '體重、體脂、圍度、每日飲水、睡眠與營養素追蹤'
                          : 'Body measurements, BMI/BMR/TDEE, hydration, sleep & macros',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => navigationController.openMoreDestination(
                      MoreSubDestination.bodyHealth,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('more_settings_tile'),
                    leading: const Icon(Icons.settings_outlined, color: Color(0xFF64D2FF)),
                    title: Text(
                      strings.tr('nav_settings'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      isZh
                          ? '語言 (EN/繁中)、液態玻璃主題、隱私同意與開發者預覽'
                          : 'Language, Liquid Glass theme, privacy consent & developer preview',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => navigationController.openMoreDestination(
                      MoreSubDestination.settings,
                    ),
                  ),
                  if (user.isAdmin) ...[
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('more_diagnostics_tile'),
                      leading: const Icon(Icons.terminal_outlined, color: Color(0xFFFF9F0A)),
                      title: Text(
                        isZh ? '管理員系統診斷 (Admin Diagnostics)' : 'Admin Diagnostics',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        isZh
                            ? '執行時間環境、RLS 連線檢查與錯誤日誌'
                            : 'Runtime environment, RLS connectivity & scrubbed event logs',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => navigationController.openMoreDestination(
                        MoreSubDestination.diagnostics,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _subTitle(MoreSubDestination sub, AppStrings strings, bool isZh) {
    switch (sub) {
      case MoreSubDestination.exerciseLibrary:
        return strings.tr('nav_library');
      case MoreSubDestination.bodyHealth:
        return strings.tr('nav_health');
      case MoreSubDestination.settings:
        return strings.tr('nav_settings');
      case MoreSubDestination.diagnostics:
        return isZh ? '管理員診斷' : 'Admin Diagnostics';
      case MoreSubDestination.hub:
        return isZh ? '更多' : 'More';
    }
  }

  Widget _buildSubScreen(MoreSubDestination sub) {
    switch (sub) {
      case MoreSubDestination.exerciseLibrary:
        return ExerciseLibraryScreen(
          exercises: exercises,
          prefs: prefs,
        );
      case MoreSubDestination.bodyHealth:
        return BodyHealthScreen(
          userId: user.id,
          profile: profile,
          measurements: measurements,
          healthLogs: healthLogs,
          prefs: prefs,
          onSaveMeasurement: onSaveMeasurement,
          onSaveHealthLog: onSaveHealthLog,
        );
      case MoreSubDestination.diagnostics:
        if (!user.isAdmin) {
          return const Center(child: Text('Access Denied'));
        }
        return DiagnosticsScreen(
          config: config,
          user: user,
          dbService: dbService,
          diagnostics: diagnostics,
          prefs: prefs,
        );
      case MoreSubDestination.settings:
      case MoreSubDestination.hub:
        return SettingsScreen(
          config: config,
          user: user,
          profile: profile,
          workouts: workouts,
          measurements: measurements,
          detections: detections,
          prefs: prefs,
          authService: authService,
          dbService: dbService,
          diagnostics: diagnostics,
          onUpgradeGuest: onUpgradeGuest,
        );
    }
  }
}
