import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/screens/auth/password_management_sheet.dart';
import 'package:ai_gym_flutter/screens/diagnostics/diagnostics_screen.dart';
import 'package:ai_gym_flutter/services/auth_service.dart';
import 'package:ai_gym_flutter/services/database_service.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Complete Settings Screen covering Appearance, Training, Privacy, Account,
/// Data Export (JSON/CSV), Application Status, and Admin Developer Tools (Section 21).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.config,
    required this.user,
    required this.profile,
    required this.workouts,
    required this.measurements,
    required this.detections,
    required this.prefs,
    required this.authService,
    required this.dbService,
    required this.diagnostics,
    required this.onUpgradeGuest,
  });

  final AppConfig config;
  final AppUser user;
  final UserProfile? profile;
  final List<WorkoutRecord> workouts;
  final List<BodyMeasurement> measurements;
  final List<CameraDetectionRecord> detections;
  final PreferenceService prefs;
  final AuthService authService;
  final DatabaseService dbService;
  final DiagnosticsService diagnostics;
  final VoidCallback onUpgradeGuest;

  Future<void> _handleCameraConsentToggle(
    BuildContext context,
    bool enable,
    bool isZh,
  ) async {
    if (!enable) {
      await prefs.setCameraSaveConsentEnabled(false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isZh ? '開啟原始偵測影像上傳同意' : 'Explicit Consent for Camera Image Storage',
        ),
        content: Text(
          isZh
              ? '開啟後，當您在 AI 視覺頁面點擊「儲存偵測結果至 Supabase」時，原始照片將一併加密儲存至您個人的私人 camera-detections 儲存桶。您可隨時關閉此選項。是否同意開啟？'
              : 'When enabled, saving a camera detection will also upload the captured photo into your private, RLS-protected Supabase Storage bucket (camera-detections). Do you explicitly consent?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isZh ? '取消' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isZh ? '我同意開啟' : 'I Consent'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await prefs.setCameraSaveConsentEnabled(true);
    }
  }

  void _showExportDialog(
    BuildContext context, {
    required String title,
    required String content,
    required bool isZh,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isZh ? '已複製匯出資料至剪貼簿！' : 'Exported data copied to clipboard!',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: Text(isZh ? '複製內容' : 'Copy to Clipboard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, prefs.languageCode);
    final isZh = strings.isZh;
    final glass = prefs.glassThemeEnabled;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        // 1. APPEARANCE
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: strings.tr('settings_appearance'),
                icon: Icons.palette_outlined,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.tr('language_label')),
                trailing: SegmentedButton<String>(
                  key: const Key('settings_language_segmented'),
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(value: 'zh', label: Text('繁體中文')),
                  ],
                  selected: {prefs.languageCode.startsWith('zh') ? 'zh' : 'en'},
                  onSelectionChanged: (sel) =>
                      prefs.setLanguageCode(sel.first),
                ),
              ),
              SwitchListTile(
                key: const Key('settings_glass_toggle'),
                contentPadding: EdgeInsets.zero,
                title: Text(strings.tr('glass_theme_label')),
                subtitle: Text(
                  isZh
                      ? '啟用半透明毛玻璃卡片與漸層背景（較慢裝置可關閉以提升流暢度）'
                      : 'Translucent BackdropFilter panels & gradient backgrounds (disable on slower devices)',
                ),
                value: prefs.glassThemeEnabled,
                onChanged: prefs.setGlassThemeEnabled,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.tr('theme_mode_label')),
                trailing: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'system',
                      label: Text(isZh ? '系統' : 'System'),
                    ),
                    ButtonSegment(
                      value: 'light',
                      label: Text(isZh ? '淺色' : 'Light'),
                    ),
                    ButtonSegment(
                      value: 'dark',
                      label: Text(isZh ? '深色' : 'Dark'),
                    ),
                  ],
                  selected: {prefs.themeModeName},
                  onSelectionChanged: (sel) => prefs.setThemeMode(sel.first),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.tr('large_text_label')),
                value: prefs.largeTextEnabled,
                onChanged: prefs.setLargeTextEnabled,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.tr('one_handed_label')),
                value: prefs.oneHandedControlsEnabled,
                onChanged: prefs.setOneHandedControlsEnabled,
              ),
            ],
          ),
        ),

        // 2. TRAINING
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: strings.tr('settings_training'),
                icon: Icons.fitness_center_outlined,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isZh ? '重量單位 (kg / lb)' : 'Weight Units (kg / lb)'),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'metric', label: Text('kg')),
                    ButtonSegment(value: 'imperial', label: Text('lb')),
                  ],
                  selected: {prefs.unitSystem},
                  onSelectionChanged: (s) => prefs.setUnitSystem(s.first),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isZh ? '距離單位 (km / mi)' : 'Distance Units (km / mi)'),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'km', label: Text('km')),
                    ButtonSegment(value: 'mi', label: Text('mi')),
                  ],
                  selected: {prefs.distanceUnit},
                  onSelectionChanged: (s) => prefs.setDistanceUnit(s.first),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${isZh ? "預設組間休息秒數" : "Default Rest Duration"}: ${prefs.defaultRestSeconds}s',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => prefs.setDefaultRestSeconds(
                        prefs.defaultRestSeconds - 15,
                      ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      onPressed: () => prefs.setDefaultRestSeconds(
                        prefs.defaultRestSeconds + 15,
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isZh ? '完成組數後自動啟動休息計時' : 'Auto-Start Rest Timer After Set',
                ),
                value: prefs.autoStartRestTimer,
                onChanged: prefs.setAutoStartRestTimer,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isZh ? '訓練與連勝提醒通知' : 'Workout & Streak Reminders'),
                value: prefs.workoutRemindersEnabled,
                onChanged: prefs.setWorkoutRemindersEnabled,
              ),
            ],
          ),
        ),

        // 3. PRIVACY
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: strings.tr('settings_privacy'),
                icon: Icons.lock_outline,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isZh ? '私人進度照片保護 (RLS 隔離)' : 'Private Progress Photos (RLS Isolated)',
                ),
                value: prefs.privateProgressPhotosEnabled,
                onChanged: prefs.setPrivateProgressPhotosEnabled,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.tr('camera_save_consent')),
                subtitle: Text(
                  isZh
                      ? '預設關閉。需明確同意才會將原始偵測照片上傳至私人 Supabase Storage。'
                      : 'Disabled by default. Requires explicit consent to upload raw detection images.',
                ),
                value: prefs.cameraSaveConsentEnabled,
                onChanged: (v) => _handleCameraConsentToggle(context, v, isZh),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isZh ? '匿名使用分析同意' : 'Analytics Consent'),
                value: prefs.analyticsConsentEnabled,
                onChanged: prefs.setAnalyticsConsentEnabled,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isZh ? '錯誤診斷回報同意' : 'Crash Reporting Consent'),
                value: prefs.crashReportingConsentEnabled,
                onChanged: prefs.setCrashReportingConsentEnabled,
              ),
            ],
          ),
        ),

        // 4. ACCOUNT
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: strings.tr('settings_account'),
                icon: Icons.manage_accounts_outlined,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isZh ? '帳戶類型' : 'Account Type'),
                subtitle: Text(
                  user.isGuest
                      ? (isZh ? '訪客帳戶 (Guest - 僅限本機)' : 'Guest Mode (Local Only)')
                      : (user.isAdmin
                          ? (isZh ? '已驗證管理員 (Verified Admin)' : 'Verified Administrator')
                          : (isZh ? '已驗證雲端會員 (Verified Cloud)' : 'Verified Cloud Account')),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isZh ? '已驗證 Email' : 'Verified Email'),
                subtitle: Text(user.isGuest ? 'Guest (Offline)' : user.email),
              ),
              if (user.isGuest)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.icon(
                    onPressed: onUpgradeGuest,
                    icon: const Icon(Icons.upgrade),
                    label: Text(strings.tr('upgrade_guest')),
                  ),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => PasswordManagementSheet(
                            authService: authService,
                            isZh: isZh,
                            isAuthenticatedChangeMode: true,
                            initialEmail: user.email,
                          ),
                        );
                      },
                      icon: const Icon(Icons.password),
                      label: Text(strings.tr('change_password')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => PasswordManagementSheet(
                            authService: authService,
                            isZh: isZh,
                            isAuthenticatedChangeMode: false,
                            initialEmail: user.email,
                          ),
                        );
                      },
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: Text(strings.tr('send_reset_email')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final jsonStr = dbService.exportUserDataAsJson(
                          profile: profile,
                          workouts: workouts,
                          measurements: measurements,
                          detections: detections,
                        );
                        _showExportDialog(
                          context,
                          title: strings.tr('export_json'),
                          content: jsonStr,
                          isZh: isZh,
                        );
                      },
                      icon: const Icon(Icons.data_object),
                      label: Text(strings.tr('export_json')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final csvStr =
                            dbService.exportWorkoutsAsCsv(workouts);
                        _showExportDialog(
                          context,
                          title: strings.tr('export_csv'),
                          content: csvStr,
                          isZh: isZh,
                        );
                      },
                      icon: const Icon(Icons.table_chart_outlined),
                      label: Text(strings.tr('export_csv')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(strings.tr('delete_account_req')),
                      content: Text(
                        isZh
                            ? '您的帳戶刪除申請將清除本機快取並登出工作階段；雲端 auth.users 刪除將透過 Supabase cascade 自動移除相關個人資料。'
                            : 'Submitting an account deletion request clears local data and signs out; deleting the user in Supabase cascades across all owned tables.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(isZh ? '取消' : 'Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            authService.signOut(allSessions: true);
                          },
                          child: Text(isZh ? '確認並登出' : 'Confirm & Sign Out'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(strings.tr('delete_account_req')),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => authService.signOut(allSessions: false),
                      icon: const Icon(Icons.logout),
                      label: Text(strings.tr('logout')),
                    ),
                  ),
                  if (!user.isGuest) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => authService.signOut(allSessions: true),
                        icon: const Icon(Icons.devices_other),
                        label: Text(strings.tr('logout_all')),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // 5. APPLICATION & ADMIN TOOLS
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: strings.tr('settings_application'),
                icon: Icons.dns_outlined,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isZh ? '資料庫連線狀態' : 'Database Connection Status'),
                subtitle: Text(
                  config.isConfigured
                      ? 'Supabase PostgreSQL Ready (${config.supabaseUrl})'
                      : 'Not Configured (Missing SUPABASE_PUBLISHABLE_KEY)',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isZh ? '伺服器同步狀態' : 'Server Sync Status'),
                subtitle: Text(prefs.lastSyncState),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('App Version'),
                subtitle: Text('4.0.0+22 (Material 3 • Android)'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Privacy Policy & Terms of Service'),
                subtitle: Text(
                  'https://eprmvrtcpuydxhtzwfep.supabase.co/legal/privacy-and-terms (Placeholder)',
                ),
              ),
              // Admin Developer Tools strictly hidden from standard & Guest users
              if (user.isAdmin && !user.isGuest) ...[
                const Divider(height: 24),
                FilledButton.icon(
                  key: const Key('open_admin_tools_button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DiagnosticsScreen(
                          user: user,
                          config: config,
                          diagnostics: diagnostics,
                          dbService: dbService,
                          prefs: prefs,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.developer_board),
                  label: Text(strings.tr('admin_tools')),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
