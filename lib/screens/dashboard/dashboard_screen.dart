import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/utils/fitness_calculators.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/models/routine.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';
import 'package:ai_gym_flutter/widgets/social_and_plans_sheet.dart';

/// Main athlete dashboard displaying Guest Mode banner + Upgrade CTA,
/// weekly metrics, offline sync queue status, routine templates, and quick actions.
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
  });

  final AppUser user;
  final UserProfile? profile;
  final List<WorkoutRecord> workouts;
  final List<WorkoutRoutine> routines;
  final PreferenceService prefs;
  final ValueChanged<int> onNavigateTab;
  final Future<void> Function() onSyncPending;
  final VoidCallback onUpgradeGuest;

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
        GlassPanel(
          glassEnabled: glass,
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                child: Text(
                  (profile?.displayName.isNotEmpty == true
                          ? profile!.displayName[0]
                          : 'A')
                      .toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isZh
                          ? '歡迎回來，${profile?.displayName ?? user.displayName}'
                          : 'Welcome back, ${profile?.displayName ?? user.displayName}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isZh
                          ? '目標：${profile?.goal ?? "general_health"} • 器材：${profile?.equipmentAccess ?? "full_gym"}'
                          : 'Goal: ${profile?.goal ?? "general_health"} • Equipment: ${profile?.equipmentAccess ?? "full_gym"}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
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
        Row(
          children: [
            Expanded(
              child: GlassPanel(
                glassEnabled: glass,
                child: _MetricTile(
                  icon: Icons.local_fire_department,
                  label: strings.tr('consistency_streak'),
                  value: '${_computeStreakDays(workouts)} ${isZh ? "天" : "days"}',
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onNavigateTab(5),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(strings.tr('nav_camera')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
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
                  ),
                ],
              ),
            ],
          ),
        ),
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
              Text(
                user.isGuest
                    ? (isZh
                        ? '目前為本地訪客模式，紀錄儲存於本機 SharedPreferences。'
                        : 'Local Guest Mode active. Records are stored locally on device.')
                    : (isZh
                        ? '待同步佇列：${pendingQueue.length} 筆 • 狀態：${prefs.lastSyncState}'
                        : 'Pending offline queue: ${pendingQueue.length} • Status: ${prefs.lastSyncState}'),
              ),
            ],
          ),
        ),
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
        .map((w) => DateTime.utc(w.startedAt.year, w.startedAt.month, w.startedAt.day))
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
