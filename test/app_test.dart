import 'package:ai_gym_flutter/core/theme/design_tokens.dart';
import 'package:ai_gym_flutter/core/widgets/ui_state_views.dart';
import 'package:ai_gym_flutter/core/widgets/svg_vector_icons.dart';
import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/app/app.dart';
import 'package:ai_gym_flutter/controllers/navigation_controller.dart';
import 'package:ai_gym_flutter/controllers/sync_controller.dart';
import 'package:ai_gym_flutter/controllers/user_data_controller.dart';
import 'package:ai_gym_flutter/controllers/workout_controller.dart';
import 'package:ai_gym_flutter/core/errors/app_failure.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/repositories/detection_repository.dart';
import 'package:ai_gym_flutter/repositories/exercise_repository.dart';
import 'package:ai_gym_flutter/repositories/measurement_repository.dart';
import 'package:ai_gym_flutter/repositories/profile_repository.dart';
import 'package:ai_gym_flutter/repositories/workout_repository.dart';
import 'package:ai_gym_flutter/services/notification_service.dart';
import 'package:ai_gym_flutter/widgets/realtime_detection_showcase.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/core/utils/fitness_calculators.dart';
import 'package:ai_gym_flutter/core/utils/validators.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/models/workout_set.dart';
import 'package:ai_gym_flutter/screens/auth/auth_screen.dart';
import 'package:ai_gym_flutter/screens/settings/settings_screen.dart';
import 'package:ai_gym_flutter/services/auth_service.dart';
import 'package:ai_gym_flutter/services/camera_detection_service.dart';
import 'package:ai_gym_flutter/services/database_service.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1 & 2. Email, Password, and OTP Validation Tests', () {
    test('Email validation accepts valid emails and rejects invalid formats', () {
      expect(Validators.validateEmail('athlete@example.com'), isNull);
      expect(Validators.validateEmail('user.name+tag@domain.co.hk'), isNull);
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail('missing@domain'), isNotNull);
    });

    test('Password validation enforces minimum 8 characters and confirmation match', () {
      expect(Validators.validatePassword('1234567'), isNotNull);
      expect(Validators.validatePassword('StrongPass123!'), isNull);
      expect(
        Validators.validateConfirmPassword('StrongPass123!', 'StrongPass123!'),
        isNull,
      );
      expect(
        Validators.validateConfirmPassword('StrongPass123!', 'Different123!'),
        isNotNull,
      );
      expect(Validators.validateOtpCode('123456'), isNull);
      expect(Validators.validateOtpCode('12345'), isNotNull);
    });
  });

  group('3. Login State Transitions, Supabase Config & Admin Role Security Tests', () {
    test('AppConfig includes preconfigured Supabase Project, Org, and Publishable Key', () {
      final cfg = AppConfig.fromEnvironment();
      expect(cfg.supabaseProjectName, "aza610aza01-creator's Project");
      expect(cfg.supabaseOrgName, "aza610aza01-creator's Org | Supabase");
      expect(
        cfg.supabasePublishableKey,
        'sb_publishable_7psvpRTKPvrcIFZjNcynIQ_KiDD5lgP',
      );
      expect(cfg.isConfigured, isTrue);
    });

    test('AuthService transitions between unauthenticated, guest, and logout', () async {
      SharedPreferences.setMockInitialValues({});
      const config = AppConfig(
        supabaseUrl: AppConfig.defaultSupabaseUrl,
        supabasePublishableKey: '',
        adminEmail: 'admin@example.com',
      );
      final diagnostics = DiagnosticsService();
      final auth = AuthService(
        config: config,
        diagnostics: diagnostics,
        supabaseInitialized: false,
      );

      expect(auth.currentUser.stage, AuthFlowStage.unauthenticated);
      expect(auth.currentUser.isAdmin, isFalse);

      auth.enterGuestMode();
      expect(auth.currentUser.stage, AuthFlowStage.guest);
      expect(auth.currentUser.isGuest, isTrue);
      expect(auth.currentUser.isAdmin, isFalse);

      await auth.signOut();
      expect(auth.currentUser.stage, AuthFlowStage.unauthenticated);
    });

    test('Admin check requires matching ADMIN_EMAIL, OTP verified, and non-guest', () {
      const config = AppConfig(
        supabaseUrl: AppConfig.defaultSupabaseUrl,
        supabasePublishableKey: AppConfig.defaultSupabasePublishableKey,
        adminEmail: 'admin@example.com',
      );

      expect(
        config.isAdminEmail(
          'admin@example.com',
          isOtpVerified: true,
          isGuest: false,
        ),
        isTrue,
      );
      expect(
        config.isAdminEmail(
          'admin@example.com',
          isOtpVerified: false,
          isGuest: false,
        ),
        isFalse,
      );
      expect(
        config.isAdminEmail(
          'admin@example.com',
          isOtpVerified: true,
          isGuest: true,
        ),
        isFalse,
      );
      expect(
        config.isAdminEmail(
          'user@example.com',
          isOtpVerified: true,
          isGuest: false,
        ),
        isFalse,
      );
    });
  });

  group('4 & 5. Language, Glass Theme & YOLOv8 NMS Detection Tests', () {
    test('PreferenceService persists language code and Glass Theme toggle', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferenceService.create();

      expect(prefs.languageCode, 'en');
      expect(prefs.glassThemeEnabled, isTrue);
      expect(prefs.cameraSaveConsentEnabled, isFalse);

      await prefs.setLanguageCode('zh');
      expect(prefs.languageCode, 'zh');

      await prefs.setGlassThemeEnabled(false);
      expect(prefs.glassThemeEnabled, isFalse);

      await prefs.setThemeMode('light');
      expect(prefs.themeMode, ThemeMode.light);
    });

    test('YOLOv8 Non-Maximum Suppression (NMS) suppresses overlapping duplicate boxes', () {
      final now = DateTime.utc(2026, 10, 21);
      final boxes = <CameraDetectionRecord>[
        CameraDetectionRecord(
          id: 'b1',
          userId: 'u1',
          label: 'YOLO: dumbbell',
          confidence: 0.94,
          boundingBox: const Rect.fromLTRB(50, 50, 200, 200),
          sourceWidth: 720,
          sourceHeight: 1280,
          detectedAt: now,
          classId: 0,
        ),
        CameraDetectionRecord(
          id: 'b2',
          userId: 'u1',
          label: 'YOLO: dumbbell duplicate',
          confidence: 0.62,
          boundingBox: const Rect.fromLTRB(55, 55, 195, 195),
          sourceWidth: 720,
          sourceHeight: 1280,
          detectedAt: now,
          classId: 0,
        ),
        CameraDetectionRecord(
          id: 'b3',
          userId: 'u1',
          label: 'YOLO: barbell',
          confidence: 0.89,
          boundingBox: const Rect.fromLTRB(300, 100, 600, 400),
          sourceWidth: 720,
          sourceHeight: 1280,
          detectedAt: now,
          classId: 1,
        ),
      ];

      final kept = CameraDetectionService.applyYoloNms(
        boxes,
        confThreshold: 0.45,
        iouThreshold: 0.45,
      );
      expect(kept.length, 2);
      expect(kept.first.id, 'b1');
      expect(kept.last.id, 'b3');
    });
  });

  group('6 & 7. Workout and Profile Data Serialization Tests', () {
    test('WorkoutRecord and WorkoutSetRecord serialize and deserialize accurately', () {
      final now = DateTime.utc(2026, 10, 19, 10, 30);
      final setRecord = WorkoutSetRecord(
        id: 'set-1',
        workoutId: 'workout-1',
        userId: 'user-1',
        exerciseId: 'seed-squat',
        exerciseName: 'Squat',
        setNumber: 1,
        reps: 8,
        weightKg: 100.0,
        rpe: 8.5,
        rir: 2,
        restSeconds: 90,
        tempo: '2-0-2-0',
        setType: 'standard',
        notes: 'Clean depth',
        createdAt: now,
      );
      final workout = WorkoutRecord(
        id: 'workout-1',
        userId: 'user-1',
        title: 'Lower Body Power',
        workoutType: 'strength',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 45)),
        notes: 'Felt strong',
        createdAt: now,
        sets: [setRecord],
      );

      final json = workout.toJson();
      final restored = WorkoutRecord.fromJson(json);

      expect(restored.id, 'workout-1');
      expect(restored.title, 'Lower Body Power');
      expect(restored.sets.length, 1);
      expect(restored.sets.first.exerciseName, 'Squat');
      expect(restored.totalVolumeKg, 800.0);
      expect(restored.totalReps, 8);
      expect(
        FitnessCalculators.estimateOneRepMax(weightKg: 100, reps: 8),
        closeTo(126.67, 0.1),
      );
    });

    test('UserProfile serializes and evaluates completeness accurately', () {
      const incomplete = UserProfile(
        id: 'u-1',
        displayName: 'Alex',
        onboardingCompleted: false,
      );
      expect(incomplete.isIncomplete, isTrue);

      final complete = incomplete.copyWith(
        age: 26,
        heightCm: 175.0,
        weightKg: 72.5,
        goal: 'strength',
        experienceLevel: 'intermediate',
        injuryFlags: const ['None'],
        equipmentAccess: 'full_gym',
        unitSystem: 'metric',
        language: 'zh',
        onboardingCompleted: true,
      );
      final restored = UserProfile.fromJson(complete.toJson());
      expect(restored.isIncomplete, isFalse);
      expect(restored.displayName, 'Alex');
      expect(restored.age, 26);
      expect(restored.language, 'zh');
      expect(restored.goal, 'strength');
    });
  });

  group('8, 9 & 10. Widget Rendering, Auth Screen, and Settings Language Tests', () {
    testWidgets('Basic GlassPanel and EmptyStateCard render cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassPanel(
              glassEnabled: true,
              child: EmptyStateCard(
                icon: Icons.fitness_center,
                title: 'No Workouts',
                subtitle: 'Tap to add your first session.',
              ),
            ),
          ),
        ),
      );

      expect(find.text('No Workouts'), findsOneWidget);
      expect(find.text('Tap to add your first session.'), findsOneWidget);
    });

    testWidgets('AuthScreen loads, shows missing key warning when empty, and toggles language', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferenceService.create();
      const config = AppConfig(
        supabaseUrl: AppConfig.defaultSupabaseUrl,
        supabasePublishableKey: '',
        adminEmail: '',
      );
      final diagnostics = DiagnosticsService();
      final authService = AuthService(
        config: config,
        diagnostics: diagnostics,
        supabaseInitialized: false,
      );

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: prefs,
          builder: (context, _) => MaterialApp(
            home: AuthScreen(
              config: config,
              authService: authService,
              prefs: prefs,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('auth_email_field')), findsOneWidget);
      expect(find.byKey(const Key('auth_password_field')), findsOneWidget);
      expect(find.textContaining('Supabase Configuration Required'), findsOneWidget);

      await tester.tap(find.byKey(const Key('auth_language_toggle')));
      await tester.pumpAndSettle();
      expect(prefs.languageCode, 'zh');
    });

    testWidgets('SettingsScreen switches language between English and Traditional Chinese', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferenceService.create();
      const config = AppConfig(
        supabaseUrl: AppConfig.defaultSupabaseUrl,
        supabasePublishableKey: AppConfig.defaultSupabasePublishableKey,
        adminEmail: 'admin@example.com',
      );
      final diagnostics = DiagnosticsService();
      final authService = AuthService(
        config: config,
        diagnostics: diagnostics,
        supabaseInitialized: false,
      );
      final dbService = DatabaseService(
        config: config,
        diagnostics: diagnostics,
        supabaseInitialized: false,
      );

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: prefs,
          builder: (context, _) => MaterialApp(
            home: Scaffold(
              body: SettingsScreen(
                config: config,
                user: AppUser.guest(),
                profile: null,
                workouts: const <WorkoutRecord>[],
                measurements: const <BodyMeasurement>[],
                detections: const <CameraDetectionRecord>[],
                prefs: prefs,
                authService: authService,
                dbService: dbService,
                diagnostics: diagnostics,
                onUpgradeGuest: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Appearance & Accessibility'), findsOneWidget);
      await tester.tap(find.text('繁體中文'));
      await tester.pumpAndSettle();

      expect(prefs.languageCode, 'zh');
      expect(find.text('外觀、語言與無障礙設定'), findsOneWidget);
    });
  });

  group('v4.0 Comprehensive Architecture, Sync, Draft & Real-Time Camera Tests', () {
    test('HealthController, FitnessCalculators.calculateBmi/calculateBmr, DatabaseService.isConnected, and cycleVirtualGymScene work cleanly', () {
      expect(
        FitnessCalculators.calculateBmi(weightKg: 74.5, heightCm: 176),
        closeTo(24.05, 0.05),
      );
      expect(
        FitnessCalculators.calculateBmr(
          weightKg: 74.5,
          heightCm: 176,
          age: 26,
          gender: 'male',
        ),
        closeTo(1720.0, 1.0),
      );
      final diagnostics = DiagnosticsService();
      const config = AppConfig(
        supabaseUrl: AppConfig.defaultSupabaseUrl,
        supabasePublishableKey: AppConfig.defaultSupabasePublishableKey,
        adminEmail: '',
      );
      final db = DatabaseService(
        config: config,
        diagnostics: diagnostics,
        supabaseInitialized: false,
      );
      expect(db.isConnected, isFalse);

      final cam = CameraDetectionService(diagnostics: diagnostics);
      final prevScene = cam.virtualSceneIndex;
      cam.cycleVirtualGymScene(userId: 'guest-local-user', isZh: false);
      expect(cam.virtualSceneIndex, (prevScene + 1) % 3);
      cam.dispose();
    });

    test('NavigationController maps 5 primary tabs and legacy 7-tab indices safely', () {
      final nav = NavigationController();
      expect(nav.selectedIndex, 0);
      expect(nav.currentTab, PrimaryNavTab.home);

      // Legacy index 5 (Camera) maps to Primary Tab 3 (Camera)
      nav.navigateLegacyOrPrimaryIndex(5);
      expect(nav.selectedIndex, 3);
      expect(nav.currentTab, PrimaryNavTab.camera);

      // Legacy index 2 (Exercise Library) maps to More (4) -> exerciseLibrary
      nav.navigateLegacyOrPrimaryIndex(2);
      expect(nav.selectedIndex, 4);
      expect(nav.moreSubDestination, MoreSubDestination.exerciseLibrary);

      nav.resetOnSignOut();
      expect(nav.selectedIndex, 0);
      expect(nav.moreSubDestination, MoreSubDestination.hub);
    });

    test('UserDataController prevents stale account races and updates collections immutably', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferenceService.create();
      final diagnostics = DiagnosticsService();
      const config = AppConfig(
        supabaseUrl: AppConfig.defaultSupabaseUrl,
        supabasePublishableKey: '',
        adminEmail: 'admin@example.com',
      );
      final db = DatabaseService(
        config: config,
        diagnostics: diagnostics,
        supabaseInitialized: false,
      );

      final controller = UserDataController(
        profileRepo: ProfileRepository(db: db, prefs: prefs),
        exerciseRepo: ExerciseRepository(db: db),
        workoutRepo: WorkoutRepository(db: db, prefs: prefs),
        measurementRepo: MeasurementRepository(db: db, prefs: prefs),
        detectionRepo: DetectionRepository(db: db, prefs: prefs),
        diagnostics: diagnostics,
      );

      final guestUser = AppUser.guest();
      final res = await controller.loadForUser(guestUser);
      expect(res.isSuccess, isTrue);
      expect(controller.activeUserId, guestUser.id);
      expect(controller.exercises, isNotEmpty);

      final w = WorkoutRecord(
        id: 'w-immutable-1',
        userId: guestUser.id,
        title: 'Push Session',
        startedAt: DateTime.utc(2026, 10, 22, 10),
        createdAt: DateTime.utc(2026, 10, 22, 10),
      );
      controller.upsertWorkoutInMemory(w);
      expect(controller.workouts.any((x) => x.id == 'w-immutable-1'), isTrue);

      controller.resetOnSignOut();
      expect(controller.data, isNull);
      expect(controller.activeUserId, isEmpty);
    });

    test('WorkoutDraftData autosaves, recovers sets, and recovers timestamp-based rest timer', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferenceService.create();
      final notifications = NotificationService();
      final workoutCtrl = WorkoutController(
        prefs: prefs,
        notifications: notifications,
      );

      final nowUtc = DateTime.utc(2026, 10, 22, 12, 0, 0);
      notifications.startRestTimer(90, nowOverrideUtc: nowUtc);
      expect(notifications.isRunning, isTrue);
      expect(notifications.targetEndUtc, isNotNull);

      final draft = WorkoutDraftData(
        userId: 'guest-local-user',
        title: 'Leg Day Draft',
        selectedExerciseId: 'seed-squat',
        selectedSetType: 'standard',
        weightValue: 100.0,
        repsValue: 5,
        rpeValue: 8.5,
        rirValue: 1,
        sessionNotes: 'Knee sleeves on',
        startedAtUtc: nowUtc,
        sets: [
          WorkoutSetRecord(
            id: 's-1',
            workoutId: 'pending',
            userId: 'guest-local-user',
            exerciseId: 'seed-squat',
            exerciseName: 'Barbell Squat',
            setNumber: 1,
            reps: 5,
            weightKg: 100.0,
            createdAt: nowUtc,
          ),
        ],
      );

      await workoutCtrl.autosaveDraft(draft);
      expect(workoutCtrl.hasRecoverableDraft, isTrue);

      // Simulate app resume 30 seconds later
      final freshNotif = NotificationService();
      freshNotif.recoverFromTimestamp(
        prefs.getRestTimerEndUtc(),
        totalSeconds: 90,
        nowOverrideUtc: nowUtc.add(const Duration(seconds: 30)),
      );
      expect(freshNotif.remainingRestSeconds, 60);

      await workoutCtrl.discardDraft('guest-local-user');
      expect(workoutCtrl.hasRecoverableDraft, isFalse);
      notifications.dispose();
      freshNotif.dispose();
    });

    test('SyncController computes bounded exponential backoff and migrates guest data idempotently', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferenceService.create();
      final diagnostics = DiagnosticsService();
      const config = AppConfig(
        supabaseUrl: AppConfig.defaultSupabaseUrl,
        supabasePublishableKey: '',
        adminEmail: 'admin@example.com',
      );
      final db = DatabaseService(
        config: config,
        diagnostics: diagnostics,
        supabaseInitialized: false,
      );
      final workoutRepo = WorkoutRepository(db: db, prefs: prefs);
      final measurementRepo = MeasurementRepository(db: db, prefs: prefs);
      final detectionRepo = DetectionRepository(db: db, prefs: prefs);

      final syncCtrl = SyncController(
        db: db,
        prefs: prefs,
        workoutRepo: workoutRepo,
        measurementRepo: measurementRepo,
        detectionRepo: detectionRepo,
        diagnostics: diagnostics,
      );

      final delay0 = syncCtrl.computeBackoffDelay(0, jitterFactor: 0.0);
      final delay3 = syncCtrl.computeBackoffDelay(3, jitterFactor: 0.0);
      expect(delay0.inMilliseconds, 1000);
      expect(delay3.inMilliseconds, 8000);

      await prefs.saveLocalWorkouts([
        WorkoutRecord(
          id: 'guest-w-1',
          userId: 'guest-local-user',
          title: 'Guest Squat Session',
          startedAt: DateTime.utc(2026, 10, 22),
          createdAt: DateTime.utc(2026, 10, 22),
        ),
      ]);
      expect(prefs.hasGuestDataToMigrate(), isTrue);

      final report = await syncCtrl.migrateGuestDataToAccount(
        verifiedUserId: 'verified-cloud-uid',
      );
      expect(report.workoutsMigrated, 1);
      expect(report.isCompleteSuccess, isTrue);
    });

    test('CameraDetectionService validates finite latency and populates liveShowcaseFeed', () {
      final diagnostics = DiagnosticsService();
      final cam = CameraDetectionService(diagnostics: diagnostics);

      expect(cam.liveShowcaseFeed, isNotEmpty);
      expect(cam.hasValidLatency, isTrue);
      expect(
        cam.formatToolbarStatus(isZh: false).contains('Form'),
        isTrue,
      );

      cam.setLifecycleStageForTesting(CameraLifecycleStage.permissionDenied);
      expect(cam.hasValidLatency, isFalse);
      expect(cam.formatToolbarStatus(isZh: false), 'Camera idle');
      expect(cam.formatToolbarStatus(isZh: true), '相機待機中');
      cam.dispose();
    });

    test('English and Hong Kong Traditional Chinese localization tables have complete key parity', () {
      final enKeys = AppStrings.supportedKeys;
      final zhKeys = AppStrings.zhKeys;
      expect(zhKeys.containsAll(enKeys), isTrue);
      const en = AppStrings('en');
      const zh = AppStrings('zh');
      expect(en.tr('realtime_camera_showcase'), isNotEmpty);
      expect(zh.tr('realtime_camera_showcase'), isNotEmpty);
      expect(en.tr('retry'), 'Retry');
      expect(zh.tr('retry'), '重試');
    });

    testWidgets('RealTimeDetectionShowcase renders live posture and objects at 320px width with large text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 760));
      final diagnostics = DiagnosticsService();
      final cam = CameraDetectionService(diagnostics: diagnostics);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 760),
              textScaler: TextScaler.linear(1.22),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: RealTimeDetectionShowcase(
                  cameraService: cam,
                  userId: 'guest-local-user',
                  isZh: true,
                  glassEnabled: false,
                  showOpenCameraButton: true,
                  onOpenCameraTab: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('即時相機偵測內容展示'), findsOneWidget);
      expect(tester.takeException(), isNull);
      cam.dispose();
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('v5.0 Design Tokens, StatusBadge, and NoResultsStateCard render cleanly in Light and Dark mode', (tester) async {
      bool cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const StatusBadge(
                  label: 'Form 96%',
                  color: AppDesignTokens.postureCorrectDark,
                  icon: Icons.sensors,
                ),
                NoResultsStateCard(
                  queryOrFilterSummary: 'Kettlebell Snatch',
                  isZh: false,
                  onClearFilters: () => cleared = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Form 96%'), findsOneWidget);
      expect(find.text('No Matching Results'), findsOneWidget);
      await tester.tap(find.text('Clear Filters'));
      await tester.pump();
      expect(cleared, isTrue);
    });
  });

  group('v5.2 Custom SVG Vector Icon & OTP Shield Tests', () {
    testWidgets('AiGymSvgIcon and AiGymSvgOtpHeroBadge render cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AiGymSvgIcon(AiGymSvgIconName.cameraCoach, size: 28),
                AiGymSvgIcon(AiGymSvgIconName.smtpServer, size: 28),
                AiGymSvgOtpHeroBadge(
                  primaryColor: Color(0xFF9ED756),
                  secondaryColor: Color(0xFF5CE1E6),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(AiGymSvgIcon), findsNWidgets(3));
      expect(find.byType(AiGymSvgOtpHeroBadge), findsOneWidget);
    });
  });
}
