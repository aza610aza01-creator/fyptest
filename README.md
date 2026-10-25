# AI Gym Cloud (Flutter Production Release v4.1)

**AI Gym Cloud** is a local-first Flutter fitness application with bilingual English (`en`) and Traditional Chinese (`zh-Hant`) localization, workout and routine logging, adherence analytics, body/health tracking, camera detection, and Row-Level-Security (RLS) backed Supabase cloud synchronization.

### Camera detection

On Android and iOS, the Flutter app uses Google ML Kit to detect objects in live camera frames. On Windows, it connects to the Python YOLO + MediaPipe detector in `python_gym_pose/` and displays its annotated camera stream and YOLO detections in the Flutter camera screen and showcase. Chrome/Edge web builds are camera-preview only; browser camera access requires site permission and a secure origin (`localhost` or HTTPS), and web inference is not available.

To run Windows YOLO detection, install Python 3.11, run `python_gym_pose/SETUP.bat`, then run `python_gym_pose/RUN_FLUTTER.bat` before opening the Flutter camera screen. The first start may download the standard `yolov8n-pose.pt` weights. The bridge binds to `127.0.0.1:8765`; it is intended for local desktop use and is not an authenticated remote service.

---

## 1. Repository Layout (`D-3` / `H-1`)

```text
ai_gym_cloud/
├── .env.example                 # Environment variable template (SEC-1..SEC-3)
├── analysis_options.yaml        # Flutter lints & strict analyzer configuration
├── pubspec.yaml                 # Flutter SDK & package dependencies
├── lib/
│   ├── main.dart                # Application entry point & service bootstrap
│   ├── app/
│   │   ├── app.dart             # Root AiGymCloudApp widget & stage router
│   │   ├── responsive_app_shell.dart # 5-tab mobile / NavigationRail desktop shell
│   │   └── routes.dart          # Named route constants (AppRoutes)
│   ├── controllers/             # Lifecycle-safe ChangeNotifier state controllers
│   │   ├── app_startup_controller.dart
│   │   ├── auth_flow_controller.dart
│   │   ├── health_controller.dart
│   │   ├── navigation_controller.dart
│   │   ├── sync_controller.dart
│   │   ├── user_data_controller.dart
│   │   └── workout_controller.dart
│   ├── core/
│   │   ├── constants/app_config.dart # --dart-define configuration reader
│   │   ├── errors/app_failure.dart   # Typed domain failures & AppResult<T>
│   │   ├── localization/app_localizations.dart # Bilingual EN / zh-Hant strings
│   │   ├── theme/               # Design tokens & dark glassmorphism theme
│   │   ├── utils/               # Fitness calculators (1RM, BMI, BMR) & validators
│   │   └── widgets/             # Reusable GlassPanel, SVG icons & state cards
│   ├── models/                  # Immutable domain models with JSON serialization
│   ├── repositories/            # Offline-first repositories with Supabase sync
│   ├── screens/                 # Feature screens (Auth, Onboarding, Dashboard, Workout, Library, Progress, BodyHealth, Camera, Settings, Diagnostics)
│   ├── services/                # Auth, CameraDetection, Database, Diagnostics, Notification, Preference services
│   └── widgets/                 # RealTimeDetectionShowcase, RestTimerBanner, SocialAndPlansSheet
├── supabase/
│   ├── config.toml              # Local Supabase CLI configuration
│   ├── schema.sql               # Full PostgreSQL schema & Row Level Security (RLS) policies (SEC-4)
│   ├── storage_policies.sql     # Private bucket storage RLS policies (SEC-4)
│   ├── seed.sql                 # Default exercise catalog seed data
│   └── migrations/              # Incremental RLS & storage hardening migrations
├── python_gym_pose/             # Companion desktop MediaPipe/YOLOv8 pose scripts (gym_pose.py v10)
└── test/                        # Comprehensive unit & widget test suite (QA-1..QA-5)
    ├── app_test.dart
    ├── auth_and_guest_test.dart
    ├── camera_service_test.dart
    ├── localization_test.dart
    ├── service_lifecycle_test.dart
    └── settings_and_workout_persistence_test.dart
```

---

## 2. Setup & Running Locally (`H-4`)

### Prerequisites
- Flutter SDK `>=3.13.0 <4.0.0`
- A Supabase project (optional for local-only Guest Mode; required for cloud authentication & sync)

### Step 1: Install Dependencies
```bash
flutter pub get
```

### Step 2: Configure Supabase Database & RLS (`SEC-4`)
Apply `supabase/schema.sql`, `supabase/storage_policies.sql`, and `supabase/seed.sql` in the Supabase SQL Editor or via the Supabase CLI:
```bash
supabase db reset
```

### Step 3: Run the Flutter App (`SEC-1`..`SEC-3`)
No credentials are hardcoded in source. Pass your Supabase URL and anon/publishable key via `--dart-define` (or launch without flags to test local-only **Guest Mode**):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-anon-or-publishable-key \
  --dart-define=ADMIN_EMAIL=admin@example.com
```

### Step 4: Run Static Analysis & Automated Tests (`QA-1`..`QA-5`)
```bash
flutter analyze
flutter test
```
