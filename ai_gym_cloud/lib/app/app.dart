import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/app/responsive_app_shell.dart';
import 'package:ai_gym_flutter/controllers/app_startup_controller.dart';
import 'package:ai_gym_flutter/controllers/auth_flow_controller.dart';
import 'package:ai_gym_flutter/controllers/health_controller.dart';
import 'package:ai_gym_flutter/controllers/navigation_controller.dart';
import 'package:ai_gym_flutter/controllers/sync_controller.dart';
import 'package:ai_gym_flutter/controllers/user_data_controller.dart';
import 'package:ai_gym_flutter/controllers/workout_controller.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/theme/glass_theme.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/repositories/detection_repository.dart';
import 'package:ai_gym_flutter/repositories/exercise_repository.dart';
import 'package:ai_gym_flutter/repositories/measurement_repository.dart';
import 'package:ai_gym_flutter/repositories/profile_repository.dart';
import 'package:ai_gym_flutter/repositories/workout_repository.dart';
import 'package:ai_gym_flutter/screens/auth/auth_screen.dart';
import 'package:ai_gym_flutter/screens/auth/otp_verification_screen.dart';
import 'package:ai_gym_flutter/screens/camera_detection/camera_detection_screen.dart';
import 'package:ai_gym_flutter/screens/dashboard/dashboard_screen.dart';
import 'package:ai_gym_flutter/screens/more/more_screen.dart';
import 'package:ai_gym_flutter/screens/onboarding/onboarding_screen.dart';
import 'package:ai_gym_flutter/screens/progress/progress_screen.dart';
import 'package:ai_gym_flutter/screens/workout/workout_screen.dart';
import 'package:ai_gym_flutter/services/auth_service.dart';
import 'package:ai_gym_flutter/services/camera_detection_service.dart';
import 'package:ai_gym_flutter/services/database_service.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';
import 'package:ai_gym_flutter/services/notification_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Root application widget refactored in v4.0 to delegate responsibilities to
/// focused controllers (`AppStartupController`, `AuthFlowController`,
/// `UserDataController`, `NavigationController`, `WorkoutController`,
/// `HealthController`, `SyncController`, and `ResponsiveAppShell`).
///
/// Performance guarantee: `MaterialApp` only listens to `prefs`,
/// `authFlowController`, and `userDataController`—never `cameraService` or
/// `notifications`—so high-frequency camera inference latency or rest-timer
/// ticks never rebuild `MaterialApp`.
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
    this.userDataControllerOverride,
  });

  final AppConfig config;
  final PreferenceService prefs;
  final DiagnosticsService diagnostics;
  final NotificationService notifications;
  final AuthService authService;
  final DatabaseService dbService;
  final CameraDetectionService cameraService;
  final UserDataController? userDataControllerOverride;

  @override
  State<AiGymCloudApp> createState() => _AiGymCloudAppState();
}

class _AiGymCloudAppState extends State<AiGymCloudApp>
    with WidgetsBindingObserver {
  late final ProfileRepository _profileRepo;
  late final ExerciseRepository _exerciseRepo;
  late final WorkoutRepository _workoutRepo;
  late final MeasurementRepository _measurementRepo;
  late final DetectionRepository _detectionRepo;

  late final AppStartupController _startupController;
  late final AuthFlowController _authFlowController;
  late final UserDataController _userDataController;
  late final NavigationController _navigationController;
  late final WorkoutController _workoutController;
  late final HealthController _healthController;
  late final SyncController _syncController;

  bool _ownsUserDataController = false;
  bool _guestMigrationPromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    _startupController = AppStartupController(
      config: widget.config,
      prefs: widget.prefs,
      diagnostics: widget.diagnostics,
      notifications: widget.notifications,
    );
    _authFlowController = AuthFlowController(
      authService: widget.authService,
      prefs: widget.prefs,
    );
    if (widget.userDataControllerOverride != null) {
      _userDataController = widget.userDataControllerOverride!;
      _ownsUserDataController = false;
    } else {
      _userDataController = UserDataController(
        profileRepo: _profileRepo,
        exerciseRepo: _exerciseRepo,
        workoutRepo: _workoutRepo,
        measurementRepo: _measurementRepo,
        detectionRepo: _detectionRepo,
        diagnostics: widget.diagnostics,
      );
      _ownsUserDataController = true;
    }
    _navigationController = NavigationController();
    _workoutController = WorkoutController(
      prefs: widget.prefs,
      notifications: widget.notifications,
    );
    _healthController = HealthController();
    _syncController = SyncController(
      db: widget.dbService,
      prefs: widget.prefs,
      workoutRepo: _workoutRepo,
      measurementRepo: _measurementRepo,
      detectionRepo: _detectionRepo,
      diagnostics: widget.diagnostics,
    );

    widget.authService.addListener(_onAuthStageChanged);
    _onAuthStageChanged();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.authService.removeListener(_onAuthStageChanged);
    _startupController.dispose();
    _authFlowController.dispose();
    if (_ownsUserDataController) {
      _userDataController.dispose();
    }
    _navigationController.dispose();
    _workoutController.dispose();
    _healthController.dispose();
    _syncController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isZh = widget.prefs.languageCode.toLowerCase().startsWith('zh');
    widget.notifications.onAppLifecycleChanged(state, isZh: isZh);
  }

  void _onAuthStageChanged() {
    final user = widget.authService.currentUser;
    if ((user.isFullyAuthenticated || user.isGuest) &&
        user.id != _userDataController.activeUserId) {
      _userDataController.loadForUser(user);
    } else if (user.stage == AuthFlowStage.unauthenticated) {
      _userDataController.resetOnSignOut();
      _navigationController.resetOnSignOut();
      _guestMigrationPromptShown = false;
    }
  }

  Future<void> _handleUpgradeGuest() async {
    await _authFlowController.beginGuestUpgradeToCloud();
  }

  @override
  Widget build(BuildContext context) {
    // Notice: cameraService and notifications are intentionally excluded from
    // this root Listenable.merge so high-frequency inference/timer events never
    // rebuild MaterialApp.
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.prefs,
        _authFlowController,
        _userDataController,
      ]),
      builder: (context, _) {
        final glass = widget.prefs.glassThemeEnabled;
        final user = _authFlowController.currentUser;
        final iosPreview = (widget.prefs.developerModeEnabled || user.isAdmin) &&
            widget.prefs.iosPreviewModeEnabled;
        final textScale = widget.prefs.largeTextEnabled ? 1.22 : 1.0;

        final lightTheme = GlassTheme.buildTheme(
          brightness: Brightness.light,
          glassEnabled: glass,
        );
        final darkTheme = GlassTheme.buildTheme(
          brightness: Brightness.dark,
          glassEnabled: glass,
        );

        return MaterialApp(
          title: 'AI Gym Cloud',
          debugShowCheckedModeBanner: false,
          themeMode: widget.prefs.themeMode,
          theme: iosPreview
              ? lightTheme.copyWith(platform: TargetPlatform.iOS)
              : lightTheme,
          darkTheme: iosPreview
              ? darkTheme.copyWith(platform: TargetPlatform.iOS)
              : darkTheme,
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
    final user = _authFlowController.currentUser;
    final strings = AppStrings.of(context, widget.prefs.languageCode);
    final isZh = strings.isZh;

    // 1. Unauthenticated -> Auth Screen (Sign In / Create Account / Guest)
    if (user.stage == AuthFlowStage.unauthenticated) {
      return AuthScreen(
        config: widget.config,
        authService: widget.authService,
        prefs: widget.prefs,
        initialRegisterMode: _authFlowController.openRegisterOnAuth,
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
    if (_userDataController.isLoading && _userDataController.data == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(isZh ? '正在載入您的訓練與健康資料...' : 'Loading your athlete profile...'),
            ],
          ),
        ),
      );
    }

    // 3b. Blocking initial load failure -> User-visible Error Screen + Retry + Offline Fallback
    if (_userDataController.loadFailure != null &&
        _userDataController.data == null) {
      final failure = _userDataController.loadFailure!;
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: GlassPanel(
                glassEnabled: widget.prefs.glassThemeEnabled,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 46,
                      color: Color(0xFFFF453A),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.tr('loading_failure'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      failure.localizedMessage(isZh),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          key: const Key('initial_load_retry_button'),
                          onPressed: () => _userDataController.loadForUser(
                            user,
                            forceReload: true,
                          ),
                          icon: const Icon(Icons.refresh),
                          label: Text(strings.tr('retry')),
                        ),
                        OutlinedButton.icon(
                          key: const Key('initial_load_continue_offline_button'),
                          onPressed: () =>
                              _userDataController.continueWithOfflineFallback(
                            user,
                          ),
                          icon: const Icon(Icons.offline_bolt_outlined),
                          label: Text(strings.tr('offline')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final profile = _userDataController.profile;

    // 4. Incomplete profile on verified cloud account -> Onboarding Screen
    if (!user.isGuest && profile != null && profile.isIncomplete) {
      return OnboardingScreen(
        initialProfile: profile,
        prefs: widget.prefs,
        onComplete: (completed) async {
          final saved = await _profileRepo.upsertProfile(
            profile: completed,
            isGuest: user.isGuest,
          );
          if (!mounted) return;
          _userDataController.updateProfileInMemory(saved);
        },
      );
    }

    // 4b. Offer safe Guest-to-Cloud migration banner/dialog when a verified
    //     cloud account has local guest records awaiting import.
    if (user.isFullyAuthenticated &&
        widget.prefs.pendingGuestMigration &&
        !_guestMigrationPromptShown) {
      _guestMigrationPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showGuestMigrationDialog(context, user, strings);
      });
    }

    // 5. Main 5-Destination Responsive Shell
    //    [0] Home (Dashboard + Real-Time Camera Detection Showcase)
    //    [1] Workout (with Draft Autosave/Recovery)
    //    [2] Progress (Analytics, Goals, PRs)
    //    [3] Camera (Real-Time YOLOv8-Pose + Equipment/Cloth Showcase)
    //    [4] More (Exercise Library, Body & Health, Settings, Diagnostics)
    final pages = <Widget>[
      DashboardScreen(
        user: user,
        profile: profile,
        workouts: _userDataController.workouts,
        routines: _userDataController.routines,
        goals: _userDataController.goals,
        measurements: _userDataController.measurements,
        detections: _userDataController.detections,
        prefs: widget.prefs,
        cameraService: widget.cameraService,
        syncController: _syncController,
        onNavigateTab: _navigationController.navigateLegacyOrPrimaryIndex,
        onSyncPending: () async {
          await _syncController.syncPendingOperations(
            userId: user.id,
            isGuest: user.isGuest,
          );
          final refreshed = await _workoutRepo.fetchWorkouts(
            userId: user.id,
            isGuest: user.isGuest,
          );
          if (!mounted) return;
          _userDataController.replaceWorkoutsInMemory(refreshed);
        },
        onUpgradeGuest: _handleUpgradeGuest,
      ),
      WorkoutScreen(
        userId: user.id,
        exercises: _userDataController.exercises,
        routines: _userDataController.routines,
        prefs: widget.prefs,
        notifications: widget.notifications,
        onSaveWorkout: (workout) async {
          final saved = await _workoutRepo.saveWorkout(
            workout: workout,
            isGuest: user.isGuest,
          );
          if (mounted) {
            _userDataController.upsertWorkoutInMemory(saved);
          }
          return saved;
        },
        onSaveRoutine: (routine) async {
          await _workoutRepo.saveRoutine(
            routine: routine,
            isGuest: user.isGuest,
          );
          if (mounted) {
            _userDataController.upsertRoutineInMemory(routine);
          }
        },
        onSaveCardio: (cardio) async {
          await _workoutRepo.saveCardioLog(
            log: cardio,
            isGuest: user.isGuest,
          );
        },
      ),
      ProgressScreen(
        userId: user.id,
        profile: profile,
        workouts: _userDataController.workouts,
        exercises: _userDataController.exercises,
        measurements: _userDataController.measurements,
        goals: _userDataController.goals,
        prefs: widget.prefs,
        onSaveGoal: (goal) async {
          await _workoutRepo.saveGoal(goal: goal, isGuest: user.isGuest);
          if (mounted) {
            _userDataController.upsertGoalInMemory(goal);
          }
        },
      ),
      CameraDetectionScreen(
        userId: user.id,
        isGuest: user.isGuest,
        cameraService: widget.cameraService,
        prefs: widget.prefs,
        savedDetections: _userDataController.detections,
        onSaveDetection: (det, filePath) async {
          final saved = await _detectionRepo.saveDetection(
            detection: det,
            isGuest: user.isGuest,
            localCapturedFilePath: filePath,
          );
          if (mounted) {
            _userDataController.upsertDetectionInMemory(saved);
          }
        },
      ),
      MoreScreen(
        navigationController: _navigationController,
        config: widget.config,
        user: user,
        profile: profile,
        exercises: _userDataController.exercises,
        workouts: _userDataController.workouts,
        measurements: _userDataController.measurements,
        healthLogs: _userDataController.healthLogs,
        detections: _userDataController.detections,
        prefs: widget.prefs,
        authService: widget.authService,
        dbService: widget.dbService,
        diagnostics: widget.diagnostics,
        onSaveMeasurement: (m) async {
          await _measurementRepo.saveMeasurement(
            measurement: m,
            isGuest: user.isGuest,
          );
          if (mounted) {
            _userDataController.upsertMeasurementInMemory(m);
          }
        },
        onSaveHealthLog: (h) async {
          await _measurementRepo.saveHealthLog(
            log: h,
            isGuest: user.isGuest,
          );
          if (mounted) {
            _userDataController.upsertHealthLogInMemory(h);
          }
        },
        onUpgradeGuest: _handleUpgradeGuest,
      ),
    ];

    return ResponsiveAppShell(
      user: user,
      prefs: widget.prefs,
      navigationController: _navigationController,
      syncController: _syncController,
      cameraService: widget.cameraService,
      notifications: widget.notifications,
      pages: pages,
      onSyncNow: () async {
        await _syncController.syncPendingOperations(
          userId: user.id,
          isGuest: user.isGuest,
        );
      },
    );
  }

  Future<void> _showGuestMigrationDialog(
    BuildContext context,
    AppUser verifiedUser,
    AppStrings strings,
  ) async {
    final isZh = strings.isZh;
    final importNow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.tr('guest_migration')),
        content: Text(strings.tr('guest_migration_prompt')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.tr('guest_migration_skip_btn')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.tr('guest_migration_import_btn')),
          ),
        ],
      ),
    );

    if (importNow == true) {
      final report = await _syncController.migrateGuestDataToAccount(
        verifiedUserId: verifiedUser.id,
      );
      if (report.isCompleteSuccess) {
        await widget.prefs.clearGuestDataAfterMigration();
      }
      await _userDataController.loadForUser(verifiedUser, forceReload: true);
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(
            isZh
                ? '已成功匯入 ${report.totalMigrated} 筆訪客紀錄至雲端帳戶！'
                : 'Migrated ${report.totalMigrated} guest records to your verified account!',
          ),
        ),
      );
    } else {
      await widget.prefs.setPendingGuestMigration(false);
    }
  }
}
