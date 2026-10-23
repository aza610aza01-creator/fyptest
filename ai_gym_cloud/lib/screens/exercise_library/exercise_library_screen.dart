import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/core/widgets/ui_state_views.dart';
import 'package:ai_gym_flutter/models/exercise.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Searchable Exercise Library with muscle group & equipment filters,
/// coaching cues, common mistakes, instructions, and media placeholders.
class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({
    super.key,
    required this.exercises,
    required this.prefs,
  });

  final List<Exercise> exercises;
  final PreferenceService prefs;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedMuscle = 'All';
  String _selectedEquipment = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, widget.prefs.languageCode);
    final isZh = strings.isZh;
    final glass = widget.prefs.glassThemeEnabled;

    final muscles = <String>{
      'All',
      ...widget.exercises.map((e) => e.muscleGroup),
    }.toList();
    final equipments = <String>{
      'All',
      ...widget.exercises.map((e) => e.equipment),
    }.toList();

    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = widget.exercises.where((e) {
      final matchesName =
          query.isEmpty || e.name.toLowerCase().contains(query);
      final matchesMuscle =
          _selectedMuscle == 'All' || e.muscleGroup == _selectedMuscle;
      final matchesEquip =
          _selectedEquipment == 'All' || e.equipment == _selectedEquipment;
      return matchesName && matchesMuscle && matchesEquip;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: strings.tr('search_exercises'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: muscles.map((m) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(m),
                        selected: _selectedMuscle == m,
                        onSelected: (_) => setState(() => _selectedMuscle = m),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: equipments.map((eq) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(eq),
                        selected: _selectedEquipment == eq,
                        onSelected: (_) =>
                            setState(() => _selectedEquipment = eq),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        if (filtered.isEmpty)
          GlassPanel(
            glassEnabled: glass,
            child: NoResultsStateCard(
              queryOrFilterSummary: query.isNotEmpty
                  ? query
                  : '$_selectedMuscle / $_selectedEquipment',
              isZh: isZh,
              onClearFilters: () {
                setState(() {
                  _searchCtrl.clear();
                  _selectedMuscle = 'All';
                  _selectedEquipment = 'All';
                });
              },
            ),
          )
        else
          ...filtered.map(
            (ex) => GlassPanel(
              glassEnabled: glass,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: const Icon(Icons.sports_gymnastics),
                ),
                title: Text(
                  ex.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${ex.muscleGroup} • ${ex.equipment}'
                  '${ex.secondaryMuscles.isNotEmpty ? " • +${ex.secondaryMuscles.join(", ")}" : ""}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showExerciseDetailModal(context, ex, strings),
              ),
            ),
          ),
      ],
    );
  }

  void _showExerciseDetailModal(
    BuildContext context,
    Exercise ex,
    AppStrings strings,
  ) {
    final isZh = strings.isZh;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ex.name,
                        style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(ex.muscleGroup)),
                    Chip(label: Text(ex.equipment)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(ctx)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.ondemand_video_outlined, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isZh
                              ? '動作示範媒體預留位置（待配置影片 CDN 後載入：${ex.demoUrl ?? "N/A"}）'
                              : 'Exercise Demo Media Placeholder (loads when video hosting is configured: ${ex.demoUrl ?? "N/A"})',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  strings.tr('instructions'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(ex.instructions),
                const SizedBox(height: 12),
                Text(
                  strings.tr('coaching_cues'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                ...ex.cues.map((c) => Text('• $c')),
                const SizedBox(height: 12),
                Text(
                  strings.tr('common_mistakes'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                ...ex.commonMistakes.map((m) => Text('• $m')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
