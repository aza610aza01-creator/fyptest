import 'package:flutter/material.dart';
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

  group('3. Login State Transitions & Admin Role Security Tests', () {
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
        supabasePublishableKey: 'pub_test_key_1234567890',
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

  group('4 & 5. Language and Glass Theme Preference Persistence Tests', () {
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

    testWidgets('AuthScreen loads, shows missing key warning, and toggles language', (tester) async {
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
        supabasePublishableKey: 'pub_key_1234567890',
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
}
