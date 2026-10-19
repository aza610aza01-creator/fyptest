import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/utils/fitness_calculators.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/exercise.dart';
import 'package:ai_gym_flutter/models/health_and_coaching_models.dart';
import 'package:ai_gym_flutter/models/routine.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/models/workout_set.dart';
import 'package:ai_gym_flutter/services/notification_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Complete Workout, Routine Template, and Cardio/Warm-up/Mobility Logger (Sections 11 & 12).
/// Supports set-by-set logging, quick +/- weight & rep controls, RPE & RIR,
/// all 6 set types (standard, warmup, superset, drop_set, circuit, amrap),
/// auto-starting rest timer, exercise swap, session notes, and completion summary.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({
    super.key,
    required this.userId,
    required this.exercises,
    required this.routines,
    required this.prefs,
    required this.notifications,
    required this.onSaveWorkout,
    required this.onSaveRoutine,
    required this.onSaveCardio,
  });

  final String userId;
  final List<Exercise> exercises;
  final List<WorkoutRoutine> routines;
  final PreferenceService prefs;
  final NotificationService notifications;
  final Future<WorkoutRecord> Function(WorkoutRecord workout) onSaveWorkout;
  final Future<void> Function(WorkoutRoutine routine) onSaveRoutine;
  final Future<void> Function(CardioLogRecord cardio) onSaveCardio;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final Uuid _uuid = const Uuid();
  final TextEditingController _titleCtrl =
      TextEditingController(text: 'Strength & Hypertrophy Session');
  final TextEditingController _sessionNotesCtrl = TextEditingController();
  final TextEditingController _setNotesCtrl = TextEditingController();

  late String _selectedExerciseId;
  String _selectedSetType = 'standard';
  double _weightValue = 60.0;
  int _repsValue = 8;
  double _rpeValue = 8.0;
  int _rirValue = 2;
  DateTime _sessionStart = DateTime.now().toUtc();
  final List<WorkoutSetRecord> _activeSets = <WorkoutSetRecord>[];
  bool _isSaving = false;

  // Cardio / Warm-up / Mobility fields
  String _cardioType = 'Running';
  int _cardioMinutes = 20;
  double _cardioDistance = 3.5;
  int _cardioHeartRate = 142;

  @override
  void initState() {
    super.initState();
    _selectedExerciseId = widget.exercises.isNotEmpty
        ? widget.exercises.first.id
        : 'seed-squat';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _sessionNotesCtrl.dispose();
    _setNotesCtrl.dispose();
    super.dispose();
  }

  Exercise get _currentExercise {
    if (widget.exercises.isEmpty) {
      return Exercise.defaultSeedExercises().first;
    }
    return widget.exercises.firstWhere(
      (e) => e.id == _selectedExerciseId,
      orElse: () => widget.exercises.first,
    );
  }

  void _addSetToSession(bool isZh) {
    final isImperial = widget.prefs.isImperialWeight;
    final weightKg = FitnessCalculators.toKilograms(
      _weightValue,
      isImperial: isImperial,
    );

    final newSet = WorkoutSetRecord(
      id: _uuid.v4(),
      workoutId: 'pending',
      userId: widget.userId,
      exerciseId: _currentExercise.id,
      exerciseName: _currentExercise.name,
      setNumber: _activeSets.length + 1,
      reps: _repsValue,
      weightKg: double.parse(weightKg.toStringAsFixed(2)),
      rpe: _rpeValue,
      rir: _rirValue,
      restSeconds: widget.prefs.defaultRestSeconds,
      setType: _selectedSetType,
      notes: _setNotesCtrl.text.trim(),
      createdAt: DateTime.now().toUtc(),
    );

    setState(() {
      _activeSets.add(newSet);
      _setNotesCtrl.clear();
    });

    if (widget.prefs.autoStartRestTimer) {
      widget.notifications.startRestTimer(
        widget.prefs.defaultRestSeconds,
        isZh: isZh,
      );
    }
  }

  void _swapExerciseSet(int index, Exercise replacement) {
    setState(() {
      _activeSets[index] = _activeSets[index].copyWith(
        exerciseId: replacement.id,
        exerciseName: replacement.name,
      );
    });
  }

  void _loadRoutineTemplate(WorkoutRoutine routine) {
    setState(() {
      _titleCtrl.text = routine.name;
      _sessionStart = DateTime.now().toUtc();
      _activeSets.clear();
      int counter = 1;
      for (final item in routine.items) {
        for (int s = 0; s < item.targetSets; s++) {
          _activeSets.add(
            WorkoutSetRecord(
              id: _uuid.v4(),
              workoutId: 'pending',
              userId: widget.userId,
              exerciseId: item.exerciseId,
              exerciseName: item.exerciseName,
              setNumber: counter++,
              reps: item.targetReps,
              weightKg: item.targetWeightKg,
              rpe: 8.0,
              rir: 2,
              restSeconds: item.restSeconds,
              tempo: item.tempo,
              setType: routine.workoutMethod == 'superset'
                  ? 'superset'
                  : 'standard',
              createdAt: DateTime.now().toUtc(),
            ),
          );
        }
      }
    });
  }

  Future<void> _saveCurrentAsRoutine(bool isZh) async {
    final routineId = _uuid.v4();
    final grouped = <String, RoutineExerciseItem>{};
    int order = 1;
    for (final s in _activeSets) {
      grouped.putIfAbsent(
        s.exerciseId,
        () => RoutineExerciseItem(
          id: _uuid.v4(),
          routineId: routineId,
          exerciseId: s.exerciseId,
          exerciseName: s.exerciseName,
          ordering: order++,
          targetSets: _activeSets.where((x) => x.exerciseId == s.exerciseId).length,
          targetReps: s.reps,
          targetWeightKg: s.weightKg,
          restSeconds: s.restSeconds,
        ),
      );
    }

    final routine = WorkoutRoutine(
      id: routineId,
      userId: widget.userId,
      name: _titleCtrl.text.trim().isEmpty
          ? 'Custom Routine'
          : _titleCtrl.text.trim(),
      description: _sessionNotesCtrl.text.trim(),
      items: grouped.values.toList(),
      createdAt: DateTime.now().toUtc(),
    );

    await widget.onSaveRoutine(routine);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isZh ? '已儲存為課表範本：${routine.name}' : 'Saved routine template: ${routine.name}',
        ),
      ),
    );
  }

  Future<void> _finishWorkout(bool isZh) async {
    if (_activeSets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isZh ? '請先新增至少 1 組訓練組數。' : 'Add at least 1 set before completing the workout.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final workoutId = _uuid.v4();
    final mappedSets = _activeSets
        .asMap()
        .entries
        .map(
          (entry) => WorkoutSetRecord(
            id: entry.value.id,
            workoutId: workoutId,
            userId: widget.userId,
            exerciseId: entry.value.exerciseId,
            exerciseName: entry.value.exerciseName,
            setNumber: entry.key + 1,
            reps: entry.value.reps,
            weightKg: entry.value.weightKg,
            rpe: entry.value.rpe,
            rir: entry.value.rir,
            restSeconds: entry.value.restSeconds,
            tempo: entry.value.tempo,
            setType: entry.value.setType,
            notes: entry.value.notes,
            createdAt: entry.value.createdAt,
          ),
        )
        .toList();

    final record = WorkoutRecord(
      id: workoutId,
      userId: widget.userId,
      title: _titleCtrl.text.trim().isEmpty
          ? 'Workout Session'
          : _titleCtrl.text.trim(),
      workoutType: 'strength',
      startedAt: _sessionStart,
      endedAt: DateTime.now().toUtc(),
      notes: _sessionNotesCtrl.text.trim(),
      createdAt: DateTime.now().toUtc(),
      sets: mappedSets,
    );

    final saved = await widget.onSaveWorkout(record);
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _activeSets.clear();
      _sessionNotesCtrl.clear();
      _sessionStart = DateTime.now().toUtc();
    });

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isZh ? '訓練完成摘要' : 'Workout Completion Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${isZh ? "課表名稱" : "Session"}: ${saved.title}'),
            Text('${isZh ? "完成組數" : "Total Sets"}: ${saved.sets.length}'),
            Text('${isZh ? "總反覆次數" : "Total Reps"}: ${saved.totalReps}'),
            Text(
              '${isZh ? "總訓練容量" : "Total Volume"}: ${saved.totalVolumeKg.toStringAsFixed(1)} kg',
            ),
            const SizedBox(height: 8),
            Text(
              saved.isPendingSync
                  ? (isZh ? '狀態：已加入離線佇列（待連線自動上傳）' : 'Status: Saved to offline queue (will sync on reconnect)')
                  : (isZh ? '狀態：已同步至 Supabase' : 'Status: Synced to Supabase Cloud'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _logCardioOrMobility(bool isZh) async {
    final durationSec = _cardioMinutes * 60;
    final calories = FitnessCalculators.estimateCardioCalories(
      durationSeconds: durationSec,
      userWeightKg: 70.0,
      metValue: _cardioType == 'Running' ? 9.0 : 6.5,
    );
    final log = CardioLogRecord(
      id: _uuid.v4(),
      userId: widget.userId,
      cardioType: _cardioType,
      durationSeconds: durationSec,
      distanceKm: _cardioDistance,
      averagePace: _cardioDistance > 0
          ? '${(_cardioMinutes / _cardioDistance).toStringAsFixed(1)} min/km'
          : 'Steady',
      averageHeartRate: _cardioHeartRate,
      caloriesEstimated: calories,
      intervals: [
        {'phase': 'Warm-up', 'minutes': 5},
        {'phase': 'Working Interval', 'minutes': (_cardioMinutes - 5).clamp(1, 120)},
      ],
      createdAt: DateTime.now().toUtc(),
    );
    await widget.onSaveCardio(log);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isZh
              ? '已記錄 $_cardioType ($_cardioMinutes 分鐘 • 預估 $calories kcal)'
              : 'Logged $_cardioType ($_cardioMinutes min • Est. $calories kcal)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, widget.prefs.languageCode);
    final isZh = strings.isZh;
    final glass = widget.prefs.glassThemeEnabled;
    final isImperial = widget.prefs.isImperialWeight;
    final weightUnit = isImperial ? 'lb' : 'kg';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (widget.routines.isNotEmpty)
          GlassPanel(
            glassEnabled: glass,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: isZh ? '從課表範本開始' : 'Start from Routine Template',
                  icon: Icons.bookmark_added_outlined,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.routines
                      .map(
                        (r) => ActionChip(
                          avatar: const Icon(Icons.play_arrow, size: 18),
                          label: Text(r.name),
                          onPressed: () => _loadRoutineTemplate(r),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: strings.tr('active_workout'),
                icon: Icons.fitness_center,
                trailing: TextButton.icon(
                  onPressed:
                      _activeSets.isEmpty ? null : () => _saveCurrentAsRoutine(isZh),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(isZh ? '存為範本' : 'Save Template'),
                ),
              ),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: isZh ? '訓練課表標題' : 'Session Title',
                ),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: isZh ? '選擇訓練動作' : 'Select Exercise',
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _currentExercise.id,
                    isExpanded: true,
                    isDense: true,
                    items: widget.exercises
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.id,
                            child: Text('${e.name} (${e.muscleGroup})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedExerciseId = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: WorkoutSetRecord.supportedSetTypes.map((st) {
                  return ChoiceChip(
                    label: Text(st.toUpperCase()),
                    selected: _selectedSetType == st,
                    onSelected: (_) => setState(() => _selectedSetType = st),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StepperCard(
                      label: '${isZh ? "重量" : "Weight"} ($weightUnit)',
                      valueText: _weightValue.toStringAsFixed(1),
                      onMinus: () => setState(
                        () => _weightValue = (_weightValue - 2.5).clamp(0.0, 600.0),
                      ),
                      onPlus: () => setState(
                        () => _weightValue = (_weightValue + 2.5).clamp(0.0, 600.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StepperCard(
                      label: isZh ? '反覆次數 (Reps)' : 'Repetitions (Reps)',
                      valueText: '$_repsValue',
                      onMinus: () => setState(
                        () => _repsValue = (_repsValue - 1).clamp(1, 200),
                      ),
                      onPlus: () => setState(
                        () => _repsValue = (_repsValue + 1).clamp(1, 200),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StepperCard(
                      label: 'RPE (1-10)',
                      valueText: _rpeValue.toStringAsFixed(1),
                      onMinus: () => setState(
                        () => _rpeValue = (_rpeValue - 0.5).clamp(5.0, 10.0),
                      ),
                      onPlus: () => setState(
                        () => _rpeValue = (_rpeValue + 0.5).clamp(5.0, 10.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StepperCard(
                      label: 'RIR (0-6)',
                      valueText: '$_rirValue',
                      onMinus: () =>
                          setState(() => _rirValue = (_rirValue - 1).clamp(0, 6)),
                      onPlus: () =>
                          setState(() => _rirValue = (_rirValue + 1).clamp(0, 6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _setNotesCtrl,
                decoration: InputDecoration(
                  labelText: isZh ? '單組動作備註 (Exercise Notes)' : 'Exercise Set Notes',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _addSetToSession(isZh),
                icon: const Icon(Icons.add),
                label: Text(strings.tr('add_set')),
              ),
            ],
          ),
        ),
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: isZh
                    ? '已記錄組數 (${_activeSets.length})'
                    : 'Logged Sets (${_activeSets.length})',
                icon: Icons.format_list_numbered,
                trailing: TextButton.icon(
                  onPressed: () => widget.notifications.startRestTimer(
                    widget.prefs.defaultRestSeconds,
                    isZh: isZh,
                  ),
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(strings.tr('rest_timer')),
                ),
              ),
              if (_activeSets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    isZh ? '尚未新增組數。' : 'No sets added to this session yet.',
                  ),
                )
              else
                ..._activeSets.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;
                  final dispW = FitnessCalculators.formatWeight(
                    s.weightKg,
                    isImperial: isImperial,
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text('${idx + 1}'),
                    ),
                    title: Text(
                      '${s.exerciseName} [${s.setType.toUpperCase()}]',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${dispW.toStringAsFixed(1)} $weightUnit × ${s.reps} reps • RPE ${s.rpe ?? "-"} • RIR ${s.rir ?? "-"}'
                      '${s.notes.isNotEmpty ? " • ${s.notes}" : ""}',
                    ),
                    trailing: PopupMenuButton<Exercise>(
                      tooltip: strings.tr('swap_exercise'),
                      icon: const Icon(Icons.swap_horiz),
                      onSelected: (ex) => _swapExerciseSet(idx, ex),
                      itemBuilder: (_) => widget.exercises
                          .map(
                            (ex) => PopupMenuItem<Exercise>(
                              value: ex,
                              child: Text('${ isZh ? "替換為" : "Swap to"}: ${ex.name}'),
                            ),
                          )
                          .toList(),
                    ),
                  );
                }),
              const SizedBox(height: 10),
              TextField(
                controller: _sessionNotesCtrl,
                decoration: InputDecoration(
                  labelText: isZh ? '整體訓練總結備註 (Session Notes)' : 'Session Summary Notes',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isSaving ? null : () => _finishWorkout(isZh),
                icon: const Icon(Icons.cloud_done_outlined),
                label: Text(strings.tr('complete_workout')),
              ),
            ],
          ),
        ),
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: strings.tr('cardio_mobility'),
                icon: Icons.directions_run,
              ),
              Wrap(
                spacing: 8,
                children: [
                  'Running',
                  'Cycling',
                  'Dynamic Warm-up',
                  'Thoracic & Hip Mobility',
                  'Cooldown Stretch',
                ].map((type) {
                  return ChoiceChip(
                    label: Text(type),
                    selected: _cardioType == type,
                    onSelected: (_) => setState(() => _cardioType = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StepperCard(
                      label: isZh ? '時間 (分鐘)' : 'Duration (min)',
                      valueText: '$_cardioMinutes',
                      onMinus: () => setState(
                        () => _cardioMinutes = (_cardioMinutes - 5).clamp(5, 180),
                      ),
                      onPlus: () => setState(
                        () => _cardioMinutes = (_cardioMinutes + 5).clamp(5, 180),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StepperCard(
                      label: isZh ? '距離 (km)' : 'Distance (km)',
                      valueText: _cardioDistance.toStringAsFixed(1),
                      onMinus: () => setState(
                        () => _cardioDistance =
                            (_cardioDistance - 0.5).clamp(0.0, 100.0),
                      ),
                      onPlus: () => setState(
                        () => _cardioDistance =
                            (_cardioDistance + 0.5).clamp(0.0, 100.0),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _logCardioOrMobility(isZh),
                icon: const Icon(Icons.favorite_border),
                label: Text(
                  isZh ? '儲存有氧/熱身/活動度紀錄' : 'Log Cardio / Warm-up / Mobility',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperCard extends StatelessWidget {
  const _StepperCard({
    required this.label,
    required this.valueText,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String valueText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onMinus,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              IconButton(
                onPressed: onPlus,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
