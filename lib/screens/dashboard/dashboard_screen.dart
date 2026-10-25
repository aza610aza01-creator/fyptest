import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/controllers/sync_controller.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
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

/// Redesigned Athlete Dashboard implementing the 12-Screen Personal Trainer
/// Reference Format (Screens #5 Activities, #6 Calories Smooth Chart,
/// #7 Route Map, #8 Active Running + AI Pose + Music Player, #9 March Calendar,
/// #10 Heart BPM Graph, #11 Weekly Day Rings & Steps, and #12 2 304 cal 2x2 Grid)
/// while preserving the Kinetic Dark & Daylight Glass Theme.
class DashboardScreen extends StatefulWidget {
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

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _activeFormatScreen = 5; // Default to #5 Activities (can switch #5..#12)
  bool _musicPlaying = true;
  int _selectedMarchDay = 14;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, widget.prefs.languageCode);
    final isZh = strings.isZh;
    final glass = widget.prefs.glassThemeEnabled;
    final scheme = Theme.of(context).colorScheme;
    final heightCm = (widget.profile?.heightCm ?? 174).round();
    final weightKg = (widget.profile?.weightKg ?? 65).round();

    final paradigmItems = <(String, String)>[
      ('flat', isZh ? '🎨 扁平化 Flat' : '🎨 Flat 2D'),
      ('glassmorphism', isZh ? '💎 毛玻璃 Glass' : '💎 Glassmorphism'),
      ('neomorphism', isZh ? '☁️ 新擬態 Soft UI' : '☁️ Neomorphism'),
      ('skeuomorphism', isZh ? '📓 擬物化皮革 Skeuo' : '📓 Skeuomorphism'),
      ('dark', isZh ? '🌙 高對比深色 Dark' : '🌙 Dark Mode'),
      ('bento', isZh ? '🍱 便當盒網格 Bento' : '🍱 Bento Grid'),
    ];

    final formatTabs = <(int, String)>[
      (4, isZh ? '🍱 便當盒總覽' : '🍱 Bento Grid'),
      (5, isZh ? '#5 活動紀錄' : '#5 Activities'),
      (6, isZh ? '#6 卡路里圖' : '#6 Calories'),
      (7, isZh ? '#7 路線地圖' : '#7 Route Map'),
      (8, isZh ? '#8 跑步與姿態' : '#8 Running & Pose'),
      (9, isZh ? '#9 三月行事曆' : '#9 Calendar'),
      (10, isZh ? '#10 心率波形' : '#10 Heart BPM'),
      (11, isZh ? '#11 步數與週環' : '#11 Steps & Rings'),
      (12, isZh ? '#12 總覽四宮格' : '#12 2 304 cal Grid'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        // v6.2 6 UI/UX Design Paradigms Switcher Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: paradigmItems.map((p) {
              final isSelected = widget.prefs.designParadigm == p.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 8),
                child: ChoiceChip(
                  label: Text(
                    p.$2,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    widget.prefs.setDesignParadigm(p.$1);
                    if (p.$1 == 'bento') {
                      setState(() => _activeFormatScreen = 4);
                    } else if (p.$1 == 'skeuomorphism') {
                      setState(() => _activeFormatScreen = 9);
                    } else {
                      setState(() {});
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        // 12-Screen Reference Format Quick Selector Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: formatTabs.map((item) {
              final selected = _activeFormatScreen == item.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _activeFormatScreen = item.$1),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        if (widget.user.isGuest)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassPanel(
              glassEnabled: glass,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.tr('guest_banner'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    key: const Key('dashboard_upgrade_guest_button'),
                    onPressed: widget.onUpgradeGuest,
                    child: Text(strings.tr('upgrade_guest')),
                  ),
                ],
              ),
            ),
          ),

        // Render active screen format (#4 Bento + #5..#12)
        if (_activeFormatScreen == 4)
          _buildBentoBoxShowcase(context, isZh, glass, scheme, heightCm, weightKg),
        if (_activeFormatScreen == 5)
          _buildScreen5Activities(context, isZh, glass, scheme, heightCm, weightKg),
        if (_activeFormatScreen == 6)
          _buildScreen6CaloriesChart(context, isZh, glass, scheme),
        if (_activeFormatScreen == 7)
          _buildScreen7RouteMap(context, isZh, glass, scheme),
        if (_activeFormatScreen == 8)
          _buildScreen8ActiveRunningAndPose(context, isZh, glass, scheme),
        if (_activeFormatScreen == 9)
          _buildScreen9MarchCalendar(context, isZh, glass, scheme),
        if (_activeFormatScreen == 10)
          _buildScreen10HeartBpm(context, isZh, glass, scheme),
        if (_activeFormatScreen == 11)
          _buildScreen11StepsAndRings(context, isZh, glass, scheme),
        if (_activeFormatScreen == 12)
          _buildScreen12Summary2x2Grid(context, isZh, glass, scheme),
      ],
    );
  }


  /// v6.2 Modular Bento Box Grid / Card-Based Layout combining all 6 UI/UX Themes
  Widget _buildBentoBoxShowcase(
    BuildContext context,
    bool isZh,
    bool glass,
    ColorScheme scheme,
    int heightCm,
    int weightKg,
  ) {
    final bmi = (weightKg / ((heightCm / 100.0) * (heightCm / 100.0))).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassPanel(
          glassEnabled: glass,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isZh ? '🍱 便當盒模組化網格 (Bento Box Grid)' : '🍱 Modular Bento Box Command Grid',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    widget.prefs.designParadigm.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isZh
                    ? '整合 Flat 2D、Glassmorphism、Neomorphism (Soft UI)、Skeuomorphism 皮革日曆、Dark Mode 與 Bento 卡片容器。'
                    : 'Unifies Flat 2D, Glassmorphism, Neomorphism (Soft UI), Skeuomorphism (Leather Calendar), Dark Mode, and Bento Grid containers.',
                style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.32,
          children: [
            GlassPanel(
              glassEnabled: glass,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('☁️ SOFT UI BIOMETRICS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: scheme.primary)),
                  Text('BMI $bmi', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  Text('$heightCm cm • $weightKg kg', style: const TextStyle(fontSize: 11.5)),
                ],
              ),
            ),
            GlassPanel(
              glassEnabled: glass,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('💎 GLASS VITALS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFFF5A52))),
                  const Text('112 BPM • 4,688', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  Text(isZh ? '心率與步數即時同步' : 'Cardio Zone • 2.3L Water', style: const TextStyle(fontSize: 11.5)),
                ],
              ),
            ),
            GlassPanel(
              glassEnabled: glass,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('🎨 FLAT 2D ENERGY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: scheme.secondary)),
                  const Text('2,304 kcal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const Text('Running + Gym + Swim', style: TextStyle(fontSize: 11.5)),
                ],
              ),
            ),
            GlassPanel(
              glassEnabled: glass,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🌙 OLED DARK POSE AI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF30D158))),
                  const Text('17-KP MoveNet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const Text('60 FPS • 96% Confidence', style: TextStyle(fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SkeuomorphicLeatherNotebook(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  '📓 March 14: Running (5km) + Gym Hypertrophy (4 sets)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _activeFormatScreen = 9),
                child: const Text('Open #9 →'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Screen #5 Format: Split Height (174 cm) | Weight (65 kg) Card + Activities Feed
  Widget _buildScreen5Activities(
    BuildContext context,
    bool isZh,
    bool glass,
    ColorScheme scheme,
    int heightCm,
    int weightKg,
  ) {
    final activities = [
      ('Running', '8 566 m', '44:13 min', '17 Mar 2026', 8),
      ('Gym', '1 600 kcal', '60:20 min', '16 Mar 2026', 6),
      ('Swimming', '3 667 m', '30:10 min', '13 Mar 2026', 10),
      ('Bicycle', '13 355 m', '59:40 min', '8 Mar 2026', 7),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Split Height | Weight Card
        GlassPanel(
          glassEnabled: glass,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      isZh ? '身高 Height' : 'Height',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$heightCm cm',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: scheme.outline.withValues(alpha: 0.3),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      isZh ? '體重 Weight' : 'Weight',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$weightKg kg',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isZh ? '活動紀錄 Activities' : 'Activities',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _activeFormatScreen = 6),
              icon: const Text('All'),
              label: const Icon(Icons.chevron_right_rounded, size: 18),
            ),
          ],
        ),
        ...activities.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _activeFormatScreen = a.$5),
              child: GlassPanel(
                glassEnabled: glass,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          a.$1,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          a.$4,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          a.$2,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.secondary,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Text(
                          a.$3,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Screen #6 Format: Calories + "16 574 All" Pill + Smooth Spline Chart + < NEXT WEEK >
  Widget _buildScreen6CaloriesChart(
    BuildContext context,
    bool isZh,
    bool glass,
    ColorScheme scheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isZh ? '卡路里 Calories' : 'Calories',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scheme.primary),
              ),
              child: Text(
                '16 574 All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassPanel(
          glassEnabled: glass,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'March',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SmoothSplineChartPainter(
                    lineColor: scheme.primary,
                    dotColor: const Color(0xFFFF5A52),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('su', style: TextStyle(fontSize: 11)),
                  Text('mo', style: TextStyle(fontSize: 11)),
                  Text('tu', style: TextStyle(fontSize: 11)),
                  Text('we', style: TextStyle(fontSize: 11)),
                  Text('th', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  Text('fr', style: TextStyle(fontSize: 11)),
                  Text('sa', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => setState(() => _activeFormatScreen = 5),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            const Text(
              'NEXT WEEK',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
            IconButton(
              onPressed: () => setState(() => _activeFormatScreen = 9),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }

  /// Screen #7 Format: Route: Street Home | Distance: 5km | Level: 4/5 Stars + Route Map Card
  Widget _buildScreen7RouteMap(
    BuildContext context,
    bool isZh,
    bool glass,
    ColorScheme scheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Route: Street Home', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text('Distance: 5 km', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Level:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text('★★★★☆', style: TextStyle(fontSize: 15, color: Color(0xFFFFB020), letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 12),
        GlassPanel(
          glassEnabled: glass,
          padding: const EdgeInsets.all(0),
          child: SizedBox(
            height: 320,
            width: double.infinity,
            child: CustomPaint(
              painter: _RouteMapPainter(pathColor: scheme.secondary, pinColor: scheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  /// Screen #8 Format: Running + 02:30:45 + 71 bpm / -160 cal + Live AI Pose Showcase + Music Player Bar
  Widget _buildScreen8ActiveRunningAndPose(
    BuildContext context,
    bool isZh,
    bool glass,
    ColorScheme scheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.16),
                border: Border.all(color: scheme.primary, width: 2),
              ),
              child: Icon(Icons.directions_run_rounded, color: scheme.primary, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Running', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  SizedBox(height: 2),
                  Text('⏱ 02: 30: 45', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => widget.onNavigateTab(3),
              icon: const Icon(Icons.videocam_rounded, size: 16),
              label: Text(isZh ? '全螢幕 AI 相機' : 'Full AI Cam'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GlassPanel(
          glassEnabled: glass,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('71 bpm', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              Text('- 160 cal', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (widget.cameraService != null)
          RealTimeDetectionShowcase(
            cameraService: widget.cameraService!,
            userId: widget.user.id,
            isZh: isZh,
            glassEnabled: glass,
            onOpenCameraTab: () => widget.onNavigateTab(3),
            showOpenCameraButton: true,
          ),
        const SizedBox(height: 10),
        // Bottom Music Player Bar matching Reference Screen #8
        GlassPanel(
          glassEnabled: glass,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              const Text('Counting Stars', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              Text(
                'OneRepublic',
                style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.skip_previous_rounded)),
                  IconButton(
                    onPressed: () => setState(() => _musicPlaying = !_musicPlaying),
                    icon: Icon(_musicPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 34, color: scheme.primary),
                  ),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.skip_next_rounded)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Screen #9 Format: < MARCH > Calendar Grid + Running & Bench Press Workout Cards
  Widget _buildScreen9MarchCalendar(
    BuildContext context,
    bool isZh,
    bool glass,
    ColorScheme scheme,
  ) {
    const marked = {10, 14, 17, 23, 29};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassPanel(
          glassEnabled: glass,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.chevron_left_rounded),
                  Text('MARCH', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(31, (i) {
                  final d = i + 1;
                  final isMarked = marked.contains(d);
                  final isSelected = _selectedMarchDay == d;
                  return InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () => setState(() => _selectedMarchDay = d),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? scheme.primary
                            : isMarked
                                ? scheme.primary.withValues(alpha: 0.16)
                                : Colors.transparent,
                        border: isMarked
                            ? Border.all(color: scheme.primary, width: 1.5)
                            : null,
                      ),
                      child: Text(
                        '$d',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? scheme.onPrimary : scheme.onSurface,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          glassEnabled: glass,
          padding: const EdgeInsets.all(14),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Running', style: TextStyle(fontWeight: FontWeight.w800)),
              Text('8 566 m • 30:00 min'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GlassPanel(
          glassEnabled: glass,
          padding: const EdgeInsets.all(14),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Bench press', style: TextStyle(fontWeight: FontWeight.w800)),
              Text('2x10 • 2:50 min'),
            ],
          ),
        ),
      ],
    );
  }

  /// Screen #10 Format: Heart 71 bpm Circle Card + BPM Waveform Chart
  Widget _buildScreen10HeartBpm(
    BuildContext context,
    bool isZh,
    bool glass,
    ColorScheme scheme,
  ) {
    return Column(
      children: [
        GlassPanel(
          glassEnabled: glass,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF5A52).withValues(alpha: 0.16),
                  border: Border.all(color: const Color(0xFFFF5A52), width: 2),
                ),
                child: const Icon(Icons.favorite_rounded, color: Color(0xFFFF5A52), size: 42),
              ),
              const SizedBox(height: 12),
              const Text('71 bpm', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassPanel(
          glassEnabled: glass,
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _SmoothSplineChartPainter(
                lineColor: const Color(0xFFFF5A52),
                dotColor: scheme.secondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Screen #11 Format: 7-Day Rings Strip + 3 456 Steps Emblem + History List
  Widget _buildScreen11StepsAndRings(
    BuildContext context,
    bool isZh,
    bool glass,
    ColorScheme scheme,
  ) {
    const days = ['su', 'mo', 'tu', 'we', 'th', 'fr', 'sa'];
    return Column(
      children: [
        GlassPanel(
          glassEnabled: glass,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: days.map((d) {
              final active = d == 'th';
              return Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active ? scheme.secondary : scheme.primary,
                        width: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(d, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: 0.14),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.35), width: 8),
          ),
          child: Icon(Icons.directions_walk_rounded, size: 44, color: scheme.primary),
        ),
        const SizedBox(height: 10),
        const Text('3 456', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        ...[
          ('Training', '- 170 cal'),
          ('Steps', '- 165 cal'),
          ('Running', '- 213 cal'),
        ].map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassPanel(
              glassEnabled: glass,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(row.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(row.$2, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Screen #12 Format: 2 304 cal Flame Hero + 2x2 KPI Square Grid (15 067 steps, 73 bpm, 2 567 cal, 7h 38m time)
  Widget _buildScreen12Summary2x2Grid(
    BuildContext context,
    bool isZh,
    bool glass,
    ColorScheme scheme,
  ) {
    final cards = [
      (Icons.directions_walk_rounded, '15 067', 'steps', scheme.primary, 11),
      (Icons.favorite_rounded, '73', 'bpm', const Color(0xFFFF5A52), 10),
      (Icons.local_fire_department_rounded, '2 567', 'cal', const Color(0xFFFFB020), 6),
      (Icons.nightlight_round, '7h 38m', 'time', scheme.secondary, 9),
    ];

    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFB020).withValues(alpha: 0.16),
            border: Border.all(color: const Color(0xFFFFB020).withValues(alpha: 0.35), width: 8),
          ),
          child: const Icon(Icons.local_fire_department_rounded, size: 46, color: Color(0xFFFFB020)),
        ),
        const SizedBox(height: 10),
        const Text('2 304 cal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: cards.map((c) {
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _activeFormatScreen = c.$5),
              child: GlassPanel(
                glassEnabled: glass,
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(c.$1, color: c.$4, size: 28),
                    const SizedBox(height: 8),
                    Text(c.$2, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    Text(
                      c.$3,
                      style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SmoothSplineChartPainter extends CustomPainter {
  const _SmoothSplineChartPainter({
    required this.lineColor,
    required this.dotColor,
  });

  final Color lineColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(10, size.height * 0.75)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.30,
        size.width * 0.4,
        size.height * 0.65,
        size.width * 0.58,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.75,
        size.height * 0.32,
        size.width * 0.88,
        size.height * 0.22,
        size.width - 10,
        size.height * 0.26,
      );

    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = dotColor;
    canvas.drawCircle(Offset(size.width * 0.58, size.height * 0.48), 5.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SmoothSplineChartPainter oldDelegate) => false;
}

class _RouteMapPainter extends CustomPainter {
  const _RouteMapPainter({
    required this.pathColor,
    required this.pinColor,
  });

  final Color pathColor;
  final Color pinColor;

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.35), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.65), Offset(size.width, size.height * 0.52), roadPaint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.42, size.height), roadPaint);

    final routePaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final route = Path()
      ..moveTo(size.width * 0.62, size.height * 0.22)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.32,
        size.width * 0.32,
        size.height * 0.68,
        size.width * 0.24,
        size.height * 0.82,
      )
      ..cubicTo(
        size.width * 0.48,
        size.height * 0.90,
        size.width * 0.58,
        size.height * 0.62,
        size.width * 0.68,
        size.height * 0.50,
      );

    canvas.drawPath(route, routePaint);
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.50),
      7,
      Paint()..color = pinColor,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) => false;
}
