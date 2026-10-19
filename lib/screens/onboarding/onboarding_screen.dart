import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/utils/validators.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Shown after first verified login when the user profile is incomplete.
/// Collects all required Section 10 fields and displays the mandatory
/// medical/injury professional guidance statement.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.initialProfile,
    required this.prefs,
    required this.onComplete,
  });

  final UserProfile initialProfile;
  final PreferenceService prefs;
  final Future<void> Function(UserProfile completedProfile) onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _timezoneCtrl;

  late String _sex;
  late String _goal;
  late String _experience;
  late String _equipment;
  late String _unitSystem;
  late String _distanceUnit;
  late String _language;
  final Set<String> _selectedInjuries = <String>{};
  bool _saving = false;

  static const List<String> _injuryOptions = [
    'None',
    'Lower Back Sensitivity',
    'Shoulder Impingement',
    'Knee Discomfort',
    'Wrist Mobility Limit',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _nameCtrl = TextEditingController(text: p.displayName);
    _ageCtrl = TextEditingController(text: (p.age ?? 25).toString());
    _heightCtrl = TextEditingController(text: (p.heightCm ?? 172).toString());
    _weightCtrl = TextEditingController(text: (p.weightKg ?? 68).toString());
    _timezoneCtrl = TextEditingController(text: p.timezone);
    _sex = p.sex;
    _goal = p.goal;
    _experience = p.experienceLevel;
    _equipment = p.equipmentAccess;
    _unitSystem = p.unitSystem;
    _distanceUnit = widget.prefs.distanceUnit;
    _language = widget.prefs.languageCode;
    _selectedInjuries.addAll(p.injuryFlags);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _timezoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveOnboarding() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final updated = widget.initialProfile.copyWith(
      displayName: _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text.trim()) ?? 25,
      heightCm: double.tryParse(_heightCtrl.text.trim()) ?? 172.0,
      weightKg: double.tryParse(_weightCtrl.text.trim()) ?? 68.0,
      sex: _sex,
      goal: _goal,
      experienceLevel: _experience,
      injuryFlags: _selectedInjuries.toList(),
      equipmentAccess: _equipment,
      unitSystem: _unitSystem,
      language: _language,
      timezone: _timezoneCtrl.text.trim().isEmpty
          ? 'Asia/Hong_Kong'
          : _timezoneCtrl.text.trim(),
      onboardingCompleted: true,
    );

    await widget.prefs.setDistanceUnit(_distanceUnit);
    await widget.onComplete(updated);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, _language);
    final isZh = strings.isZh;
    final glass = widget.prefs.glassThemeEnabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('onboarding_title')),
      ),
      body: GlassScaffoldBackground(
        glassEnabled: glass,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassPanel(
                    glassEnabled: glass,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.tr('onboarding_subtitle'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withValues(alpha: 0.7),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.health_and_safety_outlined),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  strings.tr('medical_disclaimer'),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassPanel(
                    glassEnabled: glass,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: strings.tr('display_name'),
                          ),
                          validator: (v) =>
                              Validators.validateDisplayName(v, isZh: isZh),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _ageCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: strings.tr('age'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _heightCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: strings.tr('height_cm'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _weightCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: strings.tr('weight_kg'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildDropdown(
                          label: strings.tr('sex'),
                          value: _sex,
                          items: const [
                            ('prefer_not_to_say', 'Prefer Not to Say / 不願透露'),
                            ('male', 'Male / 男'),
                            ('female', 'Female / 女'),
                            ('other', 'Other / 其他'),
                          ],
                          onChanged: (v) => setState(() => _sex = v),
                        ),
                        const SizedBox(height: 12),
                        _buildDropdown(
                          label: strings.tr('goal'),
                          value: _goal,
                          items: const [
                            ('strength', 'Strength / 肌力提升'),
                            ('fat_loss', 'Fat Loss / 減脂塑形'),
                            ('muscle', 'Muscle Hypertrophy / 增肌'),
                            ('general_health', 'General Health / 綜合健康'),
                          ],
                          onChanged: (v) => setState(() => _goal = v),
                        ),
                        const SizedBox(height: 12),
                        _buildDropdown(
                          label: strings.tr('experience'),
                          value: _experience,
                          items: const [
                            ('beginner', 'Beginner / 初學者'),
                            ('intermediate', 'Intermediate / 中階訓練者'),
                            ('advanced', 'Advanced / 進階訓練者'),
                          ],
                          onChanged: (v) => setState(() => _experience = v),
                        ),
                        const SizedBox(height: 12),
                        _buildDropdown(
                          label: strings.tr('equipment'),
                          value: _equipment,
                          items: const [
                            ('home', 'Home (Bodyweight/Bands) / 居家訓練'),
                            ('limited_gym', 'Limited Gym (Dumbbells) / 小型健身房'),
                            ('full_gym', 'Full Gym (Barbells & Machines) / 完整健身房'),
                          ],
                          onChanged: (v) => setState(() => _equipment = v),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          strings.tr('injuries'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _injuryOptions.map((flag) {
                            final selected = _selectedInjuries.contains(flag);
                            return FilterChip(
                              label: Text(flag),
                              selected: selected,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedInjuries.add(flag);
                                  } else {
                                    _selectedInjuries.remove(flag);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdown(
                                label: isZh ? '重量單位' : 'Weight Units',
                                value: _unitSystem,
                                items: const [
                                  ('metric', 'kg (Metric)'),
                                  ('imperial', 'lb (Imperial)'),
                                ],
                                onChanged: (v) =>
                                    setState(() => _unitSystem = v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildDropdown(
                                label: isZh ? '距離單位' : 'Distance Units',
                                value: _distanceUnit,
                                items: const [
                                  ('km', 'km'),
                                  ('mi', 'mi'),
                                ],
                                onChanged: (v) =>
                                    setState(() => _distanceUnit = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdown(
                                label: strings.tr('language_label'),
                                value: _language,
                                items: const [
                                  ('en', 'English (en)'),
                                  ('zh', '繁體中文 (zh)'),
                                ],
                                onChanged: (v) => setState(() => _language = v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _timezoneCtrl,
                                decoration: InputDecoration(
                                  labelText: isZh ? '時區 (Timezone)' : 'Timezone',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _saving ? null : _saveOnboarding,
                          icon: const Icon(Icons.check),
                          label: Text(strings.tr('save_profile')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String> onChanged,
  }) {
    final effectiveValue =
        items.any((e) => e.$1 == value) ? value : items.first.$1;
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isDense: true,
          isExpanded: true,
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item.$1,
                  child: Text(item.$2, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
