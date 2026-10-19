import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/theme/glass_theme.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/models/exercise.dart';
import 'package:ai_gym_flutter/models/health_and_coaching_models.dart';
import 'package:ai_gym_flutter/models/routine.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/models/workout.dart';
import 'package:ai_gym_flutter/repositories/detection_repository.dart';
import 'package:ai_gym_flutter/repositories/exercise_repository.dart';
import 'package:ai_gym_flutter/repositories/measurement_repository.dart';
import 'package:ai_gym_flutter/repositories/profile_repository.dart';
import 'package:ai_gym_flutter/repositories/workout_repository.dart';
import 'package:ai_gym_flutter/screens/auth/auth_screen.dart';
import 'package:ai_gym_flutter/screens/auth/otp_verification_screen.dart';
import 'package:ai_gym_flutter/screens/body_health/body_health_screen.dart';
import 'package:ai_gym_flutter/screens/camera_detection/camera_detection_screen.dart';
import 'package:ai_gym_flutter/screens/dashboard/dashboard_screen.dart';
import 'package:ai_gym_flutter/screens/exercise_library/exercise_library_screen.dart';
import 'package:ai_gym_flutter/screens/onboarding/onboarding_screen.dart';
import 'package:ai_gym_flutter/screens/progress/progress_screen.dart';
import 'package:ai_gym_flutter/screens/settings/settings_screen.dart';
import 'package:ai_gym_flutter/services/auth_service.dart';
import 'package:ai_gym_flutter/services/camera_detection_service.dart';
import 'package:ai_gym_flutter/services/database_service.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';
import 'package:ai_gym_flutter/services/notification_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';
import 'package:ai_gym_flutter/widgets/rest_timer_banner.dart';

/// Root application widget managing reactive Theme, Glassmorphism, Localization,
/// Accessible Text Scaling, Auth/OTP gating, and Navigation tabs.
class AiGymCloudApp extends StatefulWidget {
  const AiGymCloudApp({
    super.key,
    required this.config,
    required this.prefs,
    required this.diagnostics,
    required this.notifications,
    required this.authService,
    required this.dbService,
    required this.cameraService,
  });

  final AppConfig config;
  final PreferenceService prefs;
  final DiagnosticsService diagnostics;
  final NotificationService notifications;
  final AuthService authService;
  final DatabaseService dbService;
  final CameraDetectionService cameraService;

  @override
  State<AiGymCloudApp> createState() => _AiGymCloudAppState();
}

class _AiGymCloudAppState extends State<AiGymCloudApp> {
  late final ProfileRepository _profileRepo;
  late final ExerciseRepository _exerciseRepo;
  late final WorkoutRepository _workoutRepo;
  late final MeasurementRepository _measurementRepo;
  late final DetectionRepository _detectionRepo;

  UserProfile? _profile;
  List<Exercise> _exercises = Exercise.defaultSeedExercises();
  List<WorkoutRecord> _workouts = const <WorkoutRecord>[];
  List<WorkoutRoutine> _routines = const <WorkoutRoutine>[];
  List<BodyMeasurement> _measurements = const <BodyMeasurement>[];
  List<HealthLogRecord> _healthLogs = const <HealthLogRecord>[];
  List<CameraDetectionRecord> _detections = const <CameraDetectionRecord>[];
  List<UserGoalRecord> _goals = const <UserGoalRecord>[];

  int _selectedIndex = 0;
  bool _loadingUserData = false;
  String _loadedUserId = '';
  bool _openRegisterOnAuth = false;

  @override
  void initState() {
    super.initState();
    _profileRepo = ProfileRepository(
      db: widget.dbService,
      prefs: widget.prefs,
    );
    _exerciseRepo = ExerciseRepository(db: widget.dbService);
    _workoutRepo = WorkoutRepository(
      db: widget.dbService,
      prefs: widget.prefs,
    );
    _measurementRepo = MeasurementRepository(
      db: widget.dbService,
      prefs: widget.prefs,
    );
    _detectionRepo = DetectionRepository(
      db: widget.dbService,
      prefs: widget.prefs,
    );
    widget.authService.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void dispose() {
    widget.authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final user = widget.authService.currentUser;
    if ((user.isFullyAuthenticated || user.isGuest) &&
        user.id != _loadedUserId) {
      _loadedUserId = user.id;
      _loadAllUserData(user);
    } else if (user.stage == AuthFlowStage.unauthenticated) {
      setState(() {
        _loadedUserId = '';
        _profile = null;
        _selectedIndex = 0;
      });
    }
  }

  Future<void> _loadAllUserData(AppUser user) async {
    setState(() => _loadingUserData = true);
    try {
      final results = await Future.wait([
        _profileRepo.fetchOrCreateProfile(
          userId: user.id,
          defaultDisplayName: user.displayName,
          isGuest: user.isGuest,
        ),
        _exerciseRepo.fetchExercises(isGuest: user.isGuest),
        _workoutRepo.fetchWorkouts(userId: user.id, isGuest: user.isGuest),
        _workoutRepo.fetchRoutines(userId: user.id, isGuest: user.isGuest),
        _measurementRepo.fetchMeasurements(
          userId: user.id,
          isGuest: user.isGuest,
        ),
        _measurementRepo.fetchHealthLogs(
          userId: user.id,
          isGuest: user.isGuest,
        ),
        _detectionRepo.fetchSavedDetections(
          userId: user.id,
          isGuest: user.isGuest,
        ),
        _workoutRepo.fetchGoals(userId: user.id, isGuest: user.isGuest),
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile;
        _exercises = results[1] as List<Exercise>;
        _workouts = results[2] as List<WorkoutRecord>;
        _routines = results[3] as List<WorkoutRoutine>;
        _measurements = results[4] as List<BodyMeasurement>;
        _healthLogs = results[5] as List<HealthLogRecord>;
        _detections = results[6] as List<CameraDetectionRecord>;
        _goals = results[7] as List<UserGoalRecord>;
      });
    } catch (e) {
      widget.diagnostics.logEvent('Initial data load fallback: ${e.runtimeType}');
    } finally {
      if (mounted) {
        setState(() => _loadingUserData = false);
      }
    }
  }

  void _handleUpgradeGuest() {
    setState(() => _openRegisterOnAuth = true);
    widget.authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.prefs, widget.authService]),
      builder: (context, _) {
        final glass = widget.prefs.glassThemeEnabled;
        final textScale = widget.prefs.largeTextEnabled ? 1.22 : 1.0;

        return MaterialApp(
          title: 'AI Gym Cloud',
          debugShowCheckedModeBanner: false,
          themeMode: widget.prefs.themeMode,
          theme: GlassTheme.buildTheme(
            brightness: Brightness.light,
            glassEnabled: glass,
          ),
          darkTheme: GlassTheme.buildTheme(
            brightness: Brightness.dark,
            glassEnabled: glass,
          ),
          locale: Locale(widget.prefs.languageCode),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: _buildStageRoot(context),
        );
      },
    );
  }

  Widget _buildStageRoot(BuildContext context) {
    final user = widget.authService.currentUser;

    // 1. Unauthenticated -> Auth Screen (Sign In / Create Account / Guest)
    if (user.stage == AuthFlowStage.unauthenticated) {
      return AuthScreen(
        config: widget.config,
        authService: widget.authService,
        prefs: widget.prefs,
        initialRegisterMode: _openRegisterOnAuth,
      );
    }

    // 2. Step-2 Email OTP Gate -> 6-digit OTP Verification Screen
    if (user.stage == AuthFlowStage.awaitingEmailOtp) {
      return OtpVerificationScreen(
        authService: widget.authService,
        prefs: widget.prefs,
      );
    }

    // 3. Loading initial profile after verification
    if (_loadingUserData && _profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 4. Incomplete profile on verified cloud account -> Onboarding Screen
    if (!user.isGuest && _profile != null && _profile!.isIncomplete) {
      return OnboardingScreen(
        initialProfile: _profile!,
        prefs: widget.prefs,
        onComplete: (completed) async {
          final saved = await _profileRepo.upsertProfile(
            profile: completed,
            isGuest: user.isGuest,
          );
          if (!mounted) return;
          setState(() => _profile = saved);
        },
      );
    }

    // 5. Main Authenticated or Guest Shell
    final strings = AppStrings.of(context, widget.prefs.languageCode);
    final isZh = strings.isZh;
    final glass = widget.prefs.glassThemeEnabled;

    final pages = <Widget>[
      DashboardScreen(
        user: user,
        profile: _profile,
        workouts: _workouts,
        routines: _routines,
        prefs: widget.prefs,
        onNavigateTab: (idx) => setState(() => _selectedIndex = idx),
        onSyncPending: () async {
          await _workoutRepo.syncPendingQueue(isGuest: user.isGuest);
          final refreshed = await _workoutRepo.fetchWorkouts(
            userId: user.id,
            isGuest: user.isGuest,
          );
          if (!mounted) return;
          setState(() => _workouts = refreshed);
        },
        onUpgradeGuest: _handleUpgradeGuest,
      ),
      WorkoutScreen(
        userId: user.id,
        exercises: _exercises,
        routines: _routines,
        prefs: widget.prefs,
        notifications: widget.notifications,
        onSaveWorkout: (workout) async {
          final saved = await _workoutRepo.saveWorkout(
            workout: workout,
            isGuest: user.isGuest,
          );
          final updated = await _workoutRepo.fetchWorkouts(
            userId: user.id,
            isGuest: user.isGuest,
          );
          if (mounted) {
            setState(() => _workouts = updated);
          }
          return saved;
        },
        onSaveRoutine: (routine) async {
          await _workoutRepo.saveRoutine(
            routine: routine,
            isGuest: user.isGuest,
          );
          final updated = await _workoutRepo.fetchRoutines(
            userId: user.id,
            isGuest: user.isGuest,
          );
          if (mounted) {
            setState(() => _routines = updated);
          }
        },
        onSaveCardio: (cardio) async {
          await _workoutRepo.saveCardioLog(
            log: cardio,
            isGuest: user.isGuest,
          );
        },
      ),
      ExerciseLibraryScreen(
        exercises: _exercises,
        prefs: widget.prefs,
      ),
      ProgressScreen(
        userId: user.id,
        profile: _profile,
        workouts: _workouts,
        exercises: _exercises,
        measurements: _measurements,
        goals: _goals,
        prefs: widget.prefs,
        onSaveGoal: (goal) async {
          await _workoutRepo.saveGoal(goal: goal, isGuest: user.isGuest);
          final updated = await _workoutRepo.fetchGoals(
            userId: user.id,
            isGuest: user.isGuest,
          );
          if (mounted) {
            setState(() => _goals = updated);
          }
        },
      ),
      BodyHealthScreen(
        userId: user.id,
        profile: _profile,
        measurements: _measurements,
        healthLogs: _healthLogs,
        prefs: widget.prefs,
        onSaveMeasurement: (m) async {
          await _measurementRepo.saveMeasurement(
            measurement: m,
            isGuest: user.isGuest,
          );
          final updated = await _measurementRepo.fetchMeasurements(
            userId: user.id,
            isGuest: user.isGuest,
          );
          if (mounted) {
            setState(() => _measurements = updated);
          }
        },
        onSaveHealthLog: (h) async {
          await _measurementRepo.saveHealthLog(
            log: h,
            isGuest: user.isGuest,
          );
          final updated = await _measurementRepo.fetchHealthLogs(
            userId: user.id,
            isGuest: user.isGuest,
          );
          if (mounted) {
            setState(() => _healthLogs = updated);
          }
        },
      ),
      CameraDetectionScreen(
        userId: user.id,
        isGuest: user.isGuest,
        cameraService: widget.cameraService,
        prefs: widget.prefs,
        savedDetections: _detections,
        onSaveDetection: (det, filePath) async {
          await _detectionRepo.saveDetection(
            detection: det,
            isGuest: user.isGuest,
            localCapturedFilePath: filePath,
          );
          final updated = await _detectionRepo.fetchSavedDetections(
            userId: user.id,
            isGuest: user.isGuest,
          );
          if (mounted) {
            setState(() => _detections = updated);
          }
        },
      ),
      SettingsScreen(
        config: widget.config,
        user: user,
        profile: _profile,
        workouts: _workouts,
        measurements: _measurements,
        detections: _detections,
        prefs: widget.prefs,
        authService: widget.authService,
        dbService: widget.dbService,
        diagnostics: widget.diagnostics,
        onUpgradeGuest: _handleUpgradeGuest,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('app_title')),
        actions: [
          IconButton(
            tooltip: strings.tr('glass_theme_label'),
            onPressed: () => widget.prefs.setGlassThemeEnabled(!glass),
            icon: Icon(glass ? Icons.blur_on : Icons.blur_off),
          ),
          TextButton(
            onPressed: () =>
                widget.prefs.setLanguageCode(isZh ? 'en' : 'zh'),
            child: Text(isZh ? 'EN' : '繁中'),
          ),
        ],
      ),
      body: GlassScaffoldBackground(
        glassEnabled: glass,
        child: Column(
          children: [
            RestTimerBanner(
              notifications: widget.notifications,
              isZh: isZh,
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.prefs.oneHandedControlsEnabled &&
              _selectedIndex != 1
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _selectedIndex = 1),
              icon: const Icon(Icons.fitness_center),
              label: Text(strings.tr('nav_workout')),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: strings.tr('nav_dashboard'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.fitness_center_outlined),
            selectedIcon: const Icon(Icons.fitness_center),
            label: strings.tr('nav_workout'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: strings.tr('nav_library'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: strings.tr('nav_progress'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.monitor_heart_outlined),
            selectedIcon: const Icon(Icons.monitor_heart),
            label: strings.tr('nav_health'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.center_focus_strong_outlined),
            selectedIcon: const Icon(Icons.center_focus_strong),
            label: strings.tr('nav_camera'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: strings.tr('nav_settings'),
          ),
        ],
      ),
    );
  }
}
