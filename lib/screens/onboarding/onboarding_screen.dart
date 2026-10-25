import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/utils/validators.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Redesigned to follow Reference Format Screen #3 (Woman / Man Circular Avatar
/// Selector + Underline Profile Inputs) and Screen #4 ("Your Level" Stacked
/// Cards: Beginner, Regular workouts, Expert + "Next >" Pill Button).
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
  late final TextEditingController _emailCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;

  int _step = 0; // 0 = Screen #3 (Woman/Man + Fields), 1 = Screen #4 (Your Level)
  late String _sex;
  late String _goal;
  late String _experience;
  late String _equipment;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _nameCtrl = TextEditingController(text: p.displayName.isEmpty ? 'Alex Chen' : p.displayName);
    _emailCtrl = TextEditingController(text: p.email.isEmpty ? 'athlete@aigymcloud.build' : p.email);
    _ageCtrl = TextEditingController(text: (p.age ?? 25).toString());
    _heightCtrl = TextEditingController(text: (p.heightCm ?? 174).toString());
    _weightCtrl = TextEditingController(text: (p.weightKg ?? 65).toString());
    _sex = p.sex.isEmpty ? 'Female' : p.sex;
    _goal = p.goal;
    _experience = p.experienceLevel;
    _equipment = p.equipmentAccess;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveOnboarding() async {
    setState(() => _saving = true);
    final updated = widget.initialProfile.copyWith(
      displayName: _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text.trim()) ?? 25,
      heightCm: double.tryParse(_heightCtrl.text.trim()) ?? 174.0,
      weightKg: double.tryParse(_weightCtrl.text.trim()) ?? 65.0,
      sex: _sex,
      goal: _goal,
      experienceLevel: _experience,
      equipmentAccess: _equipment,
    );
    await widget.onComplete(updated);
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, widget.prefs.languageCode);
    final isZh = strings.isZh;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: _step == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => setState(() => _step = 0),
              )
            : null,
        title: Text(
          _step == 0
              ? (isZh ? '個人檔案設定 (Screen #3)' : 'Profile Setup')
              : (isZh ? '您的訓練程度 (Screen #4)' : 'Your Level'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _step == 0
                  ? _buildScreen3ProfileStep(isZh, scheme)
                  : _buildScreen4LevelStep(isZh, scheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen3ProfileStep(bool isZh, ColorScheme scheme) {
    final isWoman = _sex.toLowerCase().startsWith('f');
    return GlassPanel(
      glassEnabled: widget.prefs.glassThemeEnabled,
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dual Circular Woman / Man Selector (Reference Screen #3)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GenderCircleButton(
                  label: isZh ? '女性 Woman' : 'Woman',
                  icon: Icons.woman_rounded,
                  selected: isWoman,
                  onTap: () => setState(() => _sex = 'Female'),
                ),
                const SizedBox(width: 36),
                _GenderCircleButton(
                  label: isZh ? '男性 Man' : 'Man',
                  icon: Icons.man_rounded,
                  selected: !isWoman,
                  onTap: () => setState(() => _sex = 'Male'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: isZh ? '姓名 Full Name' : 'Full Name',
                border: const UnderlineInputBorder(),
              ),
              validator: (v) => Validators.validateDisplayName(v, isZh: isZh),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: isZh ? '電子郵件 Your E-mail' : 'Your E-mail',
                border: const UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isZh ? '年齡 Age' : 'Age',
                border: const UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isZh ? '體重 Weight (kg)' : 'Weight (kg)',
                      border: const UnderlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isZh ? '身高 Height (cm)' : 'Height (cm)',
                      border: const UnderlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              isZh
                  ? '告訴我們您的基本資訊，以便為您建立最理想的訓練計畫'
                  : 'Tell us a bit about yourself so we can create the perfect plan for you',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 200,
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    setState(() => _step = 1);
                  }
                },
                child: Text(
                  isZh ? '繼續 Sign up' : 'Sign up',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreen4LevelStep(bool isZh, ColorScheme scheme) {
    final levels = [
      (
        'Beginner',
        isZh ? '初學者 Beginner' : 'Beginner',
        isZh ? '我目前沒有規律運動習慣' : 'I do not train at all',
      ),
      (
        'Intermediate',
        isZh ? '規律訓練 Regular workouts' : 'Regular workouts',
        isZh ? '我每週進行規律訓練' : 'I train regularly',
      ),
      (
        'Advanced',
        isZh ? '進階專家 Expert' : 'Expert',
        isZh ? '我是高強度專業訓練者' : "I'm professional",
      ),
    ];

    return GlassPanel(
      glassEnabled: widget.prefs.glassThemeEnabled,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...levels.map((lvl) {
            final selected = _experience == lvl.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _experience = lvl.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: selected
                        ? scheme.primary.withValues(alpha: 0.16)
                        : scheme.surface.withValues(alpha: 0.85),
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outline.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lvl.$2,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lvl.$3,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.chevron_right_rounded, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 18),
          SizedBox(
            width: 190,
            height: 44,
            child: FilledButton(
              key: const Key('onboarding_complete_button'),
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              onPressed: _saving ? null : _saveOnboarding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isZh ? '完成 Next' : 'Next',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderCircleButton extends StatelessWidget {
  const _GenderCircleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? scheme.primary.withValues(alpha: 0.18)
                  : scheme.surface.withValues(alpha: 0.85),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outline.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: 38,
              color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
