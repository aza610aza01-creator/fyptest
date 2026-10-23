import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/health_and_coaching_models.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Body Measurements, Private Photo Comparison, Daily Health/Macros,
/// Heart-Rate Zones, and Wearable/Health Connect Integration Hub (Sections 15 & 16).
class BodyHealthScreen extends StatefulWidget {
  const BodyHealthScreen({
    super.key,
    required this.userId,
    required this.profile,
    required this.measurements,
    required this.healthLogs,
    required this.prefs,
    required this.onSaveMeasurement,
    required this.onSaveHealthLog,
  });

  final String userId;
  final UserProfile? profile;
  final List<BodyMeasurement> measurements;
  final List<HealthLogRecord> healthLogs;
  final PreferenceService prefs;
  final Future<void> Function(BodyMeasurement m) onSaveMeasurement;
  final Future<void> Function(HealthLogRecord h) onSaveHealthLog;

  @override
  State<BodyHealthScreen> createState() => _BodyHealthScreenState();
}

class _BodyHealthScreenState extends State<BodyHealthScreen> {
  final Uuid _uuid = const Uuid();
  final TextEditingController _weightCtrl = TextEditingController(text: '70.0');
  final TextEditingController _bodyFatCtrl = TextEditingController(text: '16.5');
  final TextEditingController _chestCtrl = TextEditingController(text: '98.0');
  final TextEditingController _waistCtrl = TextEditingController(text: '78.0');
  final TextEditingController _armsCtrl = TextEditingController(text: '36.0');
  final TextEditingController _thighsCtrl = TextEditingController(text: '56.0');

  int _waterMl = 2000;
  double _sleepHours = 7.5;
  int _steps = 8500;
  int _calories = 2250;
  double _proteinG = 150;
  double _carbsG = 230;
  double _fatG = 70;
  int _restingHr = 62;

  static const List<HealthIntegrationDescriptor> _integrations = [
    HealthIntegrationDescriptor(
      id: 'health_connect',
      name: 'Android Health Connect',
      platformNoteEn:
          'Optional module ready. Requires Health Connect SDK permissions in AndroidManifest to sync live records.',
      platformNoteZh:
          '選用整合介面已就緒。需配置 Android Health Connect SDK 權限後方可同步即時健康紀錄。',
    ),
    HealthIntegrationDescriptor(
      id: 'apple_health',
      name: 'Apple Health & Apple Watch',
      platformNoteEn: 'Interface ready for iOS HealthKit entitlements.',
      platformNoteZh: 'iOS HealthKit 與 Apple Watch 介面預留架構。',
    ),
    HealthIntegrationDescriptor(
      id: 'wear_os_garmin_fitbit',
      name: 'Wear OS / Garmin / Fitbit',
      platformNoteEn: 'OAuth & companion wearable sync interface placeholder.',
      platformNoteZh: '穿戴式裝置 OAuth 與心率步數同步預留介面。',
    ),
    HealthIntegrationDescriptor(
      id: 'ble_ftms',
      name: 'Bluetooth HR Straps, Smart Scales & FTMS Gym Equipment',
      platformNoteEn:
          'BLE GATT (0x180D Heart Rate / 0x1826 FTMS) adapter interface ready; requires hardware pairing.',
      platformNoteZh:
          '藍牙心率帶、智能體脂秤與 FTMS 健身器材通訊介面架構（需配置實體藍牙配對）。',
    ),
  ];

  @override
  void dispose() {
    _weightCtrl.dispose();
    _bodyFatCtrl.dispose();
    _chestCtrl.dispose();
    _waistCtrl.dispose();
    _armsCtrl.dispose();
    _thighsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitMeasurement(bool isZh) async {
    final record = BodyMeasurement(
      id: _uuid.v4(),
      userId: widget.userId,
      recordedAt: DateTime.now().toUtc(),
      weightKg: double.tryParse(_weightCtrl.text.trim()),
      bodyFatPercent: double.tryParse(_bodyFatCtrl.text.trim()),
      chestCm: double.tryParse(_chestCtrl.text.trim()),
      waistCm: double.tryParse(_waistCtrl.text.trim()),
      armsCm: double.tryParse(_armsCtrl.text.trim()),
      thighsCm: double.tryParse(_thighsCtrl.text.trim()),
    );
    await widget.onSaveMeasurement(record);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isZh ? '已儲存身體圍度與體重紀錄！' : 'Body measurement saved!',
        ),
      ),
    );
  }

  Future<void> _submitHealthLog(bool isZh) async {
    final todayIso = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final log = HealthLogRecord(
      id: _uuid.v4(),
      userId: widget.userId,
      recordedDate: todayIso,
      waterMl: _waterMl,
      sleepHours: _sleepHours,
      steps: _steps,
      calories: _calories,
      proteinG: _proteinG,
      carbsG: _carbsG,
      fatG: _fatG,
      restingHeartRate: _restingHr,
    );
    await widget.onSaveHealthLog(log);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isZh ? '已儲存今日飲水、睡眠、步數與營養素紀錄！' : 'Daily health & macro log saved!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, widget.prefs.languageCode);
    final isZh = strings.isZh;
    final glass = widget.prefs.glassThemeEnabled;
    final age = widget.profile?.age ?? 28;
    final maxHr = 220 - age;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        GlassPanel(
          glassEnabled: glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: strings.tr('body_measurements'),
                icon: Icons.straighten,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isZh ? '體重 (kg)' : 'Weight (kg)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _bodyFatCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isZh ? '體脂率 (%)' : 'Body Fat (%)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chestCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isZh ? '胸圍 (cm)' : 'Chest (cm)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _waistCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isZh ? '腰圍 (cm)' : 'Waist (cm)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _armsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isZh ? '臂圍 (cm)' : 'Arms (cm)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _thighsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isZh ? '腿圍 (cm)' : 'Thighs (cm)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _submitMeasurement(isZh),
                icon: const Icon(Icons.save_outlined),
                label: Text(isZh ? '儲存身體圍度紀錄' : 'Save Body Measurements'),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isZh
                          ? '私人進度照片前後對比模組 (Side-by-Side Private Comparison)'
                          : 'Private Progress Photo Side-by-Side Comparison',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isZh
                          ? '所有進度照片受 Supabase Storage (progress-photos) RLS 保護，僅限本人帳號存取，絕不公開列出。'
                          : 'Protected by private Supabase Storage RLS (progress-photos bucket). Never publicly listed.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _PhotoComparisonSlot(
                            title: isZh ? '基準照片 (Baseline)' : 'Baseline Photo',
                            dateLabel: widget.measurements.length > 1
                                ? widget.measurements.last.recordedAt
                                    .toIso8601String()
                                    .substring(0, 10)
                                : 'Day 1',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PhotoComparisonSlot(
                            title: isZh ? '最新進度 (Current)' : 'Current Photo',
                            dateLabel: widget.measurements.isNotEmpty
                                ? widget.measurements.first.recordedAt
                                    .toIso8601String()
                                    .substring(0, 10)
                                : 'Today',
                          ),
                        ),
                      ],
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
              SectionHeader(
                title: strings.tr('health_daily_log'),
                icon: Icons.local_drink_outlined,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.water_drop_outlined, size: 18),
                    label: Text('${isZh ? "飲水" : "Water"}: $_waterMl ml (+250)'),
                    onPressed: () => setState(() => _waterMl += 250),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.bedtime_outlined, size: 18),
                    label: Text(
                      '${isZh ? "睡眠" : "Sleep"}: ${_sleepHours.toStringAsFixed(1)} h',
                    ),
                    onPressed: () => setState(
                      () => _sleepHours =
                          ((_sleepHours + 0.5) > 12 ? 6.0 : _sleepHours + 0.5),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.directions_walk, size: 18),
                    label: Text('${isZh ? "步數" : "Steps"}: $_steps (+1000)'),
                    onPressed: () => setState(() => _steps += 1000),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.restaurant_outlined, size: 18),
                    label: Text(
                      '$_calories kcal (P:${_proteinG.toInt()}g C:${_carbsG.toInt()}g F:${_fatG.toInt()}g)',
                    ),
                    onPressed: () => setState(() => _calories += 150),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isZh
                    ? '心率區間估算（依年齡 $age 歲，最大心率約 $maxHr bpm｜熱量與心率僅供一般運動估算，非醫療指標）：\n'
                        '• Zone 2 有氧燃脂區：${(maxHr * 0.6).round()}-${(maxHr * 0.7).round()} bpm\n'
                        '• Zone 4 無氧閾值區：${(maxHr * 0.8).round()}-${(maxHr * 0.9).round()} bpm'
                    : 'Heart-Rate Zones (Est. Max HR $maxHr bpm for age $age | Calorie & HR values are general estimates with physiological limitations):\n'
                        '• Zone 2 Aerobic Endurance: ${(maxHr * 0.6).round()}-${(maxHr * 0.7).round()} bpm\n'
                        '• Zone 4 Anaerobic Threshold: ${(maxHr * 0.8).round()}-${(maxHr * 0.9).round()} bpm',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _submitHealthLog(isZh),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(isZh ? '儲存今日健康與營養紀錄' : 'Save Daily Health & Macros'),
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
                title: strings.tr('integrations_hub'),
                icon: Icons.watch_outlined,
              ),
              ..._integrations.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bluetooth_searching),
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    isZh ? item.platformNoteZh : item.platformNoteEn,
                  ),
                  trailing: Chip(
                    label: Text(
                      item.sdkConfigured
                          ? (isZh ? '已連接' : 'Connected')
                          : (isZh ? '需配置 SDK' : 'SDK Not Configured'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoComparisonSlot extends StatelessWidget {
  const _PhotoComparisonSlot({
    required this.title,
    required this.dateLabel,
  });

  final String title;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_person_outlined, size: 28),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          Text(
            dateLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
