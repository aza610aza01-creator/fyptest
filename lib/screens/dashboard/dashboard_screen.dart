import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/controllers/sync_controller.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/utils/fitness_calculators.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/models/health_and_coaching_models.dart';
import 'package:ai_gym_flutter/models/routine.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/services/camera_detection_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';
import 'package:ai_gym_flutter/widgets/realtime_detection_showcase.dart';
import 'package:ai_gym_flutter/widgets/social_and_plans_sheet.dart';

/// Main athlete dashboard displaying:
/// - Real-Time Camera Detection Live Showcase right on the Home screen
/// - Guest Mode banner + safe Upgrade CTA
/// - Customizable dashboard cards (Today's workout, Weekly progress, Active goal,
///   Workout streak, Personal records, Weight trend, Recent camera analysis,
///   Sync status, and Rest-day suggestion).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.user,
    required this.profile,
    required this.workouts,
    required this.routines,
    required this.prefs,
    required this.onNavigateTab,
    required this.onSyncPending,
    required this.onUpgradeGuest,
    this.cameraService,
    this.syncController,
    this.goals = const <UserGoalRecord>[],
    this.measurements = const <BodyMeasurement>[],
    this.detections = const <CameraDetectionRecord>[],
  });

  final AppUser user;
  final UserProfile? profile;
  final List<WorkoutRecord> workouts;
  final List<WorkoutRoutine> routines;
  final PreferenceService prefs;
  final ValueChanged<int> onNavigateTab;
  final Future<void> Function() onSyncPending;
  final VoidCallback onUpgradeGuest;
  final CameraDetectionService? cameraService;
  final SyncController? syncController;
  final List<UserGoalRecord> goals;
  final List<BodyMeasurement> measurements;
  final List<CameraDetectionRecord> detections;

  void _showCustomizeDashboardSheet(BuildContext context, bool isZh) {
    final labels = <String, String>{
      'realtime_camera_showcase':
          isZh ? '即時相機偵測內容展示區' : 'Real-Time Camera Detection Showcase',
      'today_workout': isZh ? '今日訓練與快速行動' : "Today's Workout & Quick Actions",
      'weekly_progress': isZh ? '本週訓練量與最佳 1RM' : 'Weekly Progress & Best 1RM',
      'workout_streak': isZh ? '連續訓練天數與總次數' : 'Workout Streak & Totals',
      'active_goal': isZh ? '進行中目標與個人紀錄' : 'Active Goal & Personal Records',
      'weight_trend': isZh ? '體重趨勢與恢復建議' : 'Weight Trend & Rest-Day Suggestion',
      'sync_status': isZh ? '離線佇列與雲端同步狀態' : 'Global Offline & Sync Status',
    };

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: prefs,
          builder: (context, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isZh ? '自訂主頁顯示卡片' : 'Customize Dashboard Cards',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...labels.entries.map(
                      (entry) => SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value),
                        value: prefs.isDashboardCardVisible(entry.key),
                        onChanged: (val) =>
                            prefs.toggleDashboardCard(entry.key, val),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, prefs.languageCode);
    final isZh = strings.isZh;
    final glass = prefs.glassThemeEnabled;
    final isImperial = prefs.isImperialWeight;
    final weightUnit = isImperial ? 'lb' : 'kg';

    final now = DateTime.now().toUtc();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weeklyWorkouts =
        workouts.where((w) => w.startedAt.isAfter(weekAgo)).toList();
    final weeklyVolumeKg = weeklyWorkouts.fold<double>(
      0,
      (sum, w) => sum + w.totalVolumeKg,
    );
    final formattedWeeklyVol = FitnessCalculators.formatWeight(
      weeklyVolumeKg,
      isImperial: isImperial,
    );

    double best1RmKg = 0;
    for (final w in workouts) {
      for (final s in w.sets) {
        final est = FitnessCalculators.estimateOneRepMax(
          weightKg: s.weightKg,
          reps: s.reps,
        );
        if (est > best1RmKg) best1RmKg = est;
      }
    }
    final formattedBest1Rm = FitnessCalculators.formatWeight(
      best1RmKg,
      isImperial: isImperial,
    );

    final pendingQueue = prefs.getOfflineWorkoutQueue();
    final hasActiveDraft = prefs.getWorkoutDraft(user.id) != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (user.isGuest)
          GlassPanel(
            glassEnabled: glass,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.tr('guest_banner'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: onUpgradeGuest,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(strings.tr('upgrade_guest')),
                ),
              ],
            ),
          ),

        // Athlete Greeting + Customize Dashboard Action
        GlassPanel(
          glassEnabled: glass,
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                child: Text(
                  (profile?.displayName.isNotEmpty == true
                          ? profile!.displayName[0]
                          : 'A')
                      .toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isZh
                          ? '歡迎回來，${profile?.displayName ?? user.displayName}'
                          : 'Welcome back, ${profile?.displayName ?? user.displayName}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isZh
                          ? '目標：${profile?.goal ?? "general_health"} • 器材：${profile?.equipmentAccess ?? "full_gym"}'
                          : 'Goal: ${profile?.goal ?? "general_health"} • Equipment: ${profile?.equipmentAccess ?? "full_gym"}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: strings.tr('customize_dashboard'),
                onPressed: () => _showCustomizeDashboardSheet(context, isZh),
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
        ),

        // Recoverable Active Workout Draft Banner
        if (hasActiveDraft)
          GlassPanel(
            glassEnabled: glass,
            child: Row(
              children: [
                const Icon(
                  Icons.restore_rounded,
                  color: Color(0xFF30D158),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isZh
                        ? '偵測到尚未完成的訓練草稿，點擊繼續記錄。'
                        : 'An active workout draft was saved automatically. Tap to resume.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => onNavigateTab(1),
                  child: Text(strings.tr('resume_workout')),
                ),
              ],
            ),
          ),

        // 1. REAL-TIME CAMERA DETECTION LIVE SHOWCASE (Showcased directly in program Home!)
        if (cameraService != null &&
            prefs.isDashboardCardVisible('realtime_camera_showcase'))
          RealTimeDetectionShowcase(
            cameraService: cameraService!,
            userId: user.id,
            isZh: isZh,
            glassEnabled: glass,
            showOpenCameraButton: true,
            onOpenCameraTab: () => onNavigateTab(3),
          ),

        // 2. WEEKLY PROGRESS & PERSONAL RECORDS
        if (prefs.isDashboardCardVisible('weekly_progress'))
          Row(
            children: [
              Expanded(
                child: GlassPanel(
                  glassEnabled: glass,
                  child: _MetricTile(
                    icon: Icons.fitness_center,
                    label: strings.tr('weekly_volume'),
                    value: '${formattedWeeklyVol.toStringAsFixed(0)} $weightUnit',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassPanel(
                  glassEnabled: glass,
                  child: _MetricTile(
                    icon: Icons.bolt,
                    label: strings.tr('estimated_1rm'),
                    value: '${formattedBest1Rm.toStringAsFixed(1)} $weightUnit',
                  ),
                ),
              ),
            ],
          ),

        // 3. WORKOUT STREAK & TOTAL WORKOUTS
        if (prefs.isDashboardCardVisible('workout_streak'))
          Row(
            children: [
              Expanded(
                child: GlassPanel(
                  glassEnabled: glass,
                  child: _MetricTile(
                    icon: Icons.local_fire_department,
                    label: strings.tr('consistency_streak'),
                    value:
                        '${_computeStreakDays(workouts)} ${isZh ? "天" : "days"}',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassPanel(
                  glassEnabled: glass,
                  child: _MetricTile(
                    icon: Icons.history,
                    label: isZh ? '總訓練次數' : 'Total Workouts',
                    value: '${workouts.length}',
                  ),
                ),
              ),
            ],
          ),

        // 4. TODAY'S WORKOUT & QUICK ACTIONS
        if (prefs.isDashboardCardVisible('today_workout'))
          GlassPanel(
            glassEnabled: glass,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: isZh ? '快速開始行動' : 'Quick Actions',
                  icon: Icons.play_circle_outline,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => onNavigateTab(1),
                  icon: const Icon(Icons.add_task),
                  label: Text(strings.tr('quick_start_workout')),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => onNavigateTab(3),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(strings.tr('nav_camera')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => SocialAndPlansSheet(
                            isZh: isZh,
                            glassEnabled: glass,
                            currentPlan: profile?.subscriptionPlan ?? 'free',
                          ),
                        );
                      },
                      icon: const Icon(Icons.groups_outlined),
                      label: Text(isZh ? '社群與方案' : 'Community & Plans'),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // 5. ACTIVE GOAL & WEIGHT / REST-DAY SUGGESTION
        if (prefs.isDashboardCardVisible('active_goal') ||
            prefs.isDashboardCardVisible('weight_trend'))
          GlassPanel(
            glassEnabled: glass,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: isZh ? '進行中目標與恢復建議' : 'Active Goal & Recovery Guidance',
                  icon: Icons.flag_outlined,
                ),
                Text(
                  goals.isNotEmpty
                      ? '${goals.first.title}: ${goals.first.currentValue}/${goals.first.targetValue} ${goals.first.unit}'
                      : (isZh
                          ? '尚未設定個人目標，可前往「進度分析」頁面新增目標。'
                          : 'No custom goal set yet. Add a target in the Progress tab.'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  weeklyWorkouts.length >= 5
                      ? (isZh
                          ? '恢復建議：過去 7 天已完成 ${weeklyWorkouts.length} 次訓練，建議安排主動恢復或伸展日。'
                          : 'Recovery Note: ${weeklyWorkouts.length} sessions logged in the last 7 days. Consider an active mobility/recovery day.')
                      : (isZh
                          ? '訓練節奏良好：過去 7 天已完成 ${weeklyWorkouts.length} 次訓練。'
                          : 'Training Pace: ${weeklyWorkouts.length} session(s) completed in the past 7 days.'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

        // 6. GLOBAL OFFLINE & SYNC STATUS
        if (prefs.isDashboardCardVisible('sync_status'))
          GlassPanel(
            glassEnabled: glass,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: strings.tr('sync_queue_status'),
                  icon: Icons.cloud_sync_outlined,
                  trailing: pendingQueue.isNotEmpty && !user.isGuest
                      ? TextButton.icon(
                          onPressed: onSyncPending,
                          icon: const Icon(Icons.sync),
                          label: Text(strings.tr('sync_now')),
                        )
                      : null,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        (syncController?.isOnline ?? !user.isGuest)
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        size: 16,
                      ),
                      label: Text(
                        user.isGuest
                            ? (isZh ? '本機訪客模式' : 'Local Guest')
                            : ((syncController?.isOnline ?? true)
                                ? strings.tr('online')
                                : strings.tr('offline')),
                      ),
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${strings.tr("pending_sync")}: ${pendingQueue.length}',
                      ),
                    ),
                    if ((syncController?.failedItemCount ?? 0) > 0)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          isZh
                              ? '失敗項目: ${syncController!.failedItemCount}'
                              : 'Failed: ${syncController!.failedItemCount}',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  user.isGuest
                      ? (isZh
                          ? '目前為本機訪客模式，紀錄安全儲存於本機。升級雲端帳戶後可一鍵匯入。'
                          : 'Local Guest Mode active. Records are stored on device and can be migrated when you upgrade.')
                      : '${strings.tr("last_synced")}: ${prefs.lastSyncState}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

        // 7. RECENT WORKOUTS
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: isZh ? '最近訓練紀錄' : 'Recent Workouts',
                icon: Icons.event_note_outlined,
              ),
              if (workouts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    isZh
                        ? '尚無訓練紀錄，點擊上方按鈕開始您的第一次訓練！'
                        : 'No workouts logged yet. Start your first session above!',
                  ),
                )
              else
                ...workouts.take(3).map(
                      (w) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          w.isPendingSync
                              ? Icons.cloud_upload_outlined
                              : Icons.check_circle_outline,
                        ),
                        title: Text(
                          w.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${w.startedAt.toLocal().toString().substring(0, 16)} • '
                          '${w.sets.length} sets • '
                          '${FitnessCalculators.formatWeight(w.totalVolumeKg, isImperial: isImperial).toStringAsFixed(0)} $weightUnit',
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  int _computeStreakDays(List<WorkoutRecord> list) {
    if (list.isEmpty) return 0;
    final uniqueDays = list
        .map(
          (w) => DateTime.utc(
            w.startedAt.year,
            w.startedAt.month,
            w.startedAt.day,
          ),
        )
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    int streak = 1;
    for (int i = 0; i < uniqueDays.length - 1; i++) {
      if (uniqueDays[i].difference(uniqueDays[i + 1]).inDays <= 1) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: scheme.primary, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
