import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/utils/fitness_calculators.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/exercise.dart';
import 'package:ai_gym_flutter/models/health_and_coaching_models.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Progress, Analytics, Periodisation & Coaching Screen (Sections 13 & 14).
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    required this.userId,
    required this.profile,
    required this.workouts,
    required this.exercises,
    required this.measurements,
    required this.goals,
    required this.prefs,
    required this.onSaveGoal,
  });

  final String userId;
  final UserProfile? profile;
  final List<WorkoutRecord> workouts;
  final List<Exercise> exercises;
  final List<BodyMeasurement> measurements;
  final List<UserGoalRecord> goals;
  final PreferenceService prefs;
  final Future<void> Function(UserGoalRecord goal) onSaveGoal;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final TextEditingController _searchDateOrTitleCtrl = TextEditingController();
  String _selectedExerciseFilter = 'All';
  int _daysPerWeek = 4;

  @override
  void dispose() {
    _searchDateOrTitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, widget.prefs.languageCode);
    final isZh = strings.isZh;
    final glass = widget.prefs.glassThemeEnabled;
    final isImperial = widget.prefs.isImperialWeight;
    final weightUnit = isImperial ? 'lb' : 'kg';

    // Aggregate statistics safely
    int totalSets = 0;
    int totalReps = 0;
    double bestVolumeKg = 0;
    int bestDurationMin = 0;
    double best1RmKg = 0;
    final muscleSetMap = <String, int>{};
    final exerciseById = {for (final e in widget.exercises) e.id: e};

    for (final w in widget.workouts) {
      if (w.totalVolumeKg > bestVolumeKg) bestVolumeKg = w.totalVolumeKg;
      if (w.durationMinutes > bestDurationMin) {
        bestDurationMin = w.durationMinutes;
      }
      for (final s in w.sets) {
        totalSets += 1;
        totalReps += s.reps;
        final est = FitnessCalculators.estimateOneRepMax(
          weightKg: s.weightKg,
          reps: s.reps,
        );
        if (est > best1RmKg) best1RmKg = est;
        final muscle = exerciseById[s.exerciseId]?.muscleGroup ?? 'General';
        muscleSetMap[muscle] = (muscleSetMap[muscle] ?? 0) + 1;
      }
    }

    // Filter session history
    final query = _searchDateOrTitleCtrl.text.trim().toLowerCase();
    final filteredWorkouts = widget.workouts.where((w) {
      final dateStr = w.startedAt.toIso8601String().substring(0, 10);
      final matchesText = query.isEmpty ||
          w.title.toLowerCase().contains(query) ||
          dateStr.contains(query);
      final matchesEx = _selectedExerciseFilter == 'All' ||
          w.sets.any((s) => s.exerciseName == _selectedExerciseFilter);
      return matchesText && matchesEx;
    }).toList();

    // Strength trend values (oldest -> newest)
    final chronological = widget.workouts.reversed.toList();
    final volumeTrend = chronological
        .map((w) => FitnessCalculators.formatWeight(
              w.totalVolumeKg,
              isImperial: isImperial,
            ))
        .toList();
    final volumeLabels = chronological
        .map((w) => w.startedAt.toIso8601String().substring(5, 10))
        .toList();

    final weightTrend = widget.measurements.reversed
        .where((m) => m.weightKg != null)
        .map((m) => FitnessCalculators.formatWeight(
              m.weightKg!,
              isImperial: isImperial,
            ))
        .toList();

    // Latest set for auto-progression suggestion
    final latestSet = widget.workouts.isNotEmpty &&
            widget.workouts.first.sets.isNotEmpty
        ? widget.workouts.first.sets.last
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: strings.tr('progress_analytics'),
                icon: Icons.insights,
              ),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _StatChip(
                    label: strings.tr('estimated_1rm'),
                    value:
                        '${FitnessCalculators.formatWeight(best1RmKg, isImperial: isImperial).toStringAsFixed(1)} $weightUnit',
                  ),
                  _StatChip(
                    label: isZh ? '最高單次容量' : 'Best Session Volume',
                    value:
                        '${FitnessCalculators.formatWeight(bestVolumeKg, isImperial: isImperial).toStringAsFixed(0)} $weightUnit',
                  ),
                  _StatChip(
                    label: isZh ? '最長訓練時間' : 'Best Duration',
                    value: '$bestDurationMin min',
                  ),
                  _StatChip(
                    label: isZh ? '累積總組數' : 'Total Sets',
                    value: '$totalSets',
                  ),
                  _StatChip(
                    label: isZh ? '累積總次數' : 'Total Reps',
                    value: '$totalReps',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                isZh ? '各肌群每週組數分佈' : 'Sets per Muscle Group',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (muscleSetMap.isEmpty)
                Text(isZh ? '尚無肌群組數資料。' : 'No muscle group sets recorded yet.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: muscleSetMap.entries
                      .map((e) => Chip(label: Text('${e.key}: ${e.value} sets')))
                      .toList(),
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
                title: isZh ? '訓練容量趨勢圖' : 'Session Volume Trend',
                icon: Icons.show_chart,
              ),
              SimpleTrendChart(
                values: volumeTrend,
                labels: volumeLabels,
                unit: ' $weightUnit',
                emptyText: isZh
                    ? '需要至少 2 次訓練紀錄以繪製趨勢圖（避免資料不足造成誤導）。'
                    : 'Log at least 2 sessions to plot a reliable volume trend.',
              ),
              const Divider(height: 22),
              SectionHeader(
                title: isZh ? '體重變化趨勢' : 'Body Weight Trend',
                icon: Icons.monitor_weight_outlined,
              ),
              SimpleTrendChart(
                values: weightTrend,
                labels: const <String>[],
                unit: ' $weightUnit',
                emptyText: isZh
                    ? '請於「身體與健康」分頁記錄至少 2 筆體重以顯示趨勢。'
                    : 'Record at least 2 body weight entries in Body & Health to view trend.',
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
                title: isZh ? '近14天訓練一致性日曆與徽章' : '14-Day Consistency Calendar & Badges',
                icon: Icons.calendar_today_outlined,
              ),
              _buildConsistencyCalendar(context),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(
                      Icons.emoji_events,
                      color: widget.workouts.isNotEmpty
                          ? Colors.amber
                          : Colors.grey,
                    ),
                    label: Text(isZh ? '首次訓練徽章' : 'First Session Badge'),
                  ),
                  Chip(
                    avatar: Icon(
                      Icons.local_fire_department,
                      color: widget.workouts.length >= 3
                          ? Colors.orange
                          : Colors.grey,
                    ),
                    label: Text(isZh ? '穩定訓練達人' : '3-Session Consistency'),
                  ),
                  Chip(
                    avatar: Icon(
                      Icons.workspace_premium,
                      color: bestVolumeKg >= 1000 ? Colors.green : Colors.grey,
                    ),
                    label: Text(isZh ? '千公斤容量突破' : '1,000 kg Volume PR'),
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
                title: strings.tr('periodisation_coach'),
                icon: Icons.psychology_outlined,
              ),
              Text(
                FitnessCalculators.suggestProgression(
                  currentWeightKg: latestSet?.weightKg ?? 40.0,
                  achievedReps: latestSet?.reps ?? 0,
                  targetReps: 8,
                  rpe: latestSet?.rpe,
                  isZh: isZh,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(isZh ? '每週訓練天數：' : 'Days / Week: '),
                  const SizedBox(width: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 3, label: Text('3d')),
                      ButtonSegment(value: 4, label: Text('4d')),
                      ButtonSegment(value: 5, label: Text('5d')),
                    ],
                    selected: {_daysPerWeek},
                    onSelectionChanged: (s) =>
                        setState(() => _daysPerWeek = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _buildPeriodisedPlanSummary(isZh),
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _addSampleGoal(isZh),
                icon: const Icon(Icons.flag_outlined),
                label: Text(
                  isZh ? '新增目標日期與配速提醒' : 'Add Target Date Goal & Pace Alert',
                ),
              ),
              if (widget.goals.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...widget.goals.map(
                  (g) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.track_changes),
                    title: Text('${g.goalType}: ${g.currentValue}/${g.targetValue}'),
                    subtitle: Text(
                      isZh
                          ? '目標日期：${g.targetDate?.toIso8601String().substring(0, 10) ?? "未設定"} • 進度 ${(g.progressRatio * 100).toStringAsFixed(0)}%'
                          : 'Target Date: ${g.targetDate?.toIso8601String().substring(0, 10) ?? "N/A"} • ${(g.progressRatio * 100).toStringAsFixed(0)}% complete',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: isZh ? '可搜尋訓練歷史紀錄' : 'Searchable Session History',
                icon: Icons.manage_search,
              ),
              TextField(
                controller: _searchDateOrTitleCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: isZh
                      ? '搜尋日期 (YYYY-MM-DD) 或課表名稱...'
                      : 'Search by date (YYYY-MM-DD) or session title...',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'All',
                    ...widget.exercises.map((e) => e.name),
                  ].map((name) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: _selectedExerciseFilter == name,
                        onSelected: (_) =>
                            setState(() => _selectedExerciseFilter = name),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              if (filteredWorkouts.isEmpty)
                Text(
                  isZh ? '無符合篩選條件的歷史訓練。' : 'No sessions match the selected filters.',
                )
              else
                ...filteredWorkouts.map(
                  (w) => ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      w.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${w.startedAt.toIso8601String().substring(0, 10)} • '
                      '${w.sets.length} sets • '
                      '${FitnessCalculators.formatWeight(w.totalVolumeKg, isImperial: isImperial).toStringAsFixed(0)} $weightUnit',
                    ),
                    children: w.sets
                        .map(
                          (s) => ListTile(
                            dense: true,
                            title: Text(
                              'Set ${s.setNumber}: ${s.exerciseName} (${s.setType})',
                            ),
                            trailing: Text(
                              '${FitnessCalculators.formatWeight(s.weightKg, isImperial: isImperial).toStringAsFixed(1)} $weightUnit × ${s.reps}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConsistencyCalendar(BuildContext context) {
    final today = DateTime.now().toUtc();
    final activeDates = widget.workouts
        .map((w) => w.startedAt.toIso8601String().substring(0, 10))
        .toSet();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(14, (index) {
        final day = today.subtract(Duration(days: 13 - index));
        final key = day.toIso8601String().substring(0, 10);
        final trained = activeDates.contains(key);
        return Container(
          width: 38,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: trained
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Icon(
                trained ? Icons.check_circle : Icons.circle_outlined,
                size: 13,
              ),
            ],
          ),
        );
      }),
    );
  }

  String _buildPeriodisedPlanSummary(bool isZh) {
    final goal = widget.profile?.goal ?? 'general_health';
    final equip = widget.profile?.equipmentAccess ?? 'full_gym';
    final injuries = widget.profile?.injuryFlags ?? const <String>[];
    final injuryNote = injuries.isEmpty
        ? (isZh ? '無特別限制' : 'No flagged limitations')
        : injuries.join(', ');

    if (isZh) {
      return '• 4週週期化建議（目標：$goal｜器材：$equip｜每週 $_daysPerWeek 天｜傷患標記：$injuryNote）：\n'
          '  第 1-2 週：累積期 (RPE 7.5-8.0，專注標準動作控制)\n'
          '  第 3 週：強化超負荷期 (目標重量 +2.5% 或每組 +1 次)\n'
          '  第 4 週：減量恢復週 Deload (訓練量降低 20%，安排主動恢復日)\n'
          '  *註：以上為一般體能訓練原則，並非醫療診斷或處方。';
    }
    return '• 4-Week Periodised Block (Goal: $goal | Equipment: $equip | $_daysPerWeek days/wk | Flags: $injuryNote):\n'
        '  Weeks 1-2: Accumulation (RPE 7.5-8.0, controlled tempo)\n'
        '  Week 3: Intensification (+2.5% load or +1 rep on primary compounds)\n'
        '  Week 4: Deload & Recovery (-20% volume, active mobility focus)\n'
        '  *Note: General fitness guidance only, not medical advice.';
  }

  Future<void> _addSampleGoal(bool isZh) async {
    final goal = UserGoalRecord(
      id: const Uuid().v4(),
      userId: widget.userId,
      goalType: isZh ? '月度訓練容量目標 (kg)' : 'Monthly Volume Target (kg)',
      targetValue: 12000,
      currentValue: widget.workouts.fold<double>(
        0,
        (sum, w) => sum + w.totalVolumeKg,
      ),
      targetDate: DateTime.now().toUtc().add(const Duration(days: 30)),
    );
    await widget.onSaveGoal(goal);
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
