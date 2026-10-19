# AI Gym Cloud (Flutter + Supabase + ML Kit Camera Detection)

AI Gym Cloud is a complete, maintainable Flutter Android application for gym workout logging, periodised training & coaching, progress analytics, body & health tracking, real-time/capture Android camera object detection with Google ML Kit, and secure two-step account management backed by Supabase PostgreSQL, Authentication, Row Level Security (RLS), and private Storage.

---

## 1. Project Functions

- **Two-Step Account Authentication & Security**:
  - Registration with Display Name, Email, Password (>= 8 characters), Confirm Password, and Supabase Email Confirmation (`auth.users` trigger automatically provisions `public.profiles`).
  - Two-factor Email Login: verifies Email + Password via `signInWithPassword`, immediately gates access until a 6-digit Email OTP (`signInWithOtp` + `verifyOTP(type: OtpType.email)`) is verified. Includes resend countdown, change email, and cancel login controls.
  - Password Management: Forgot Password, Reset Password Email, authenticated Change Password, single-device logout, and global all-sessions logout.
  - Guest Mode: clearly labelled local-only mode with local workout logging, preferences, and one-tap **Upgrade Guest Account** flow.
  - Admin Developer Tools: strictly gated to verified `ADMIN_EMAIL` accounts after full password + Email OTP verification.
- **Bilingual Localization (`en` / `zh`)**:
  - Instant switching between English (`en`) and Traditional Chinese (`zh`) persisted in `SharedPreferences` without restarting the app.
  - Technical terms (`Supabase`, `ML Kit`, `RPE`, `RIR`, `FPS`, `Android`, `Email`, `OTP`, `SQL`, `JSON`, `API`) remain in English for clarity.
- **User-Selectable Glassmorphism Theme (Glass Theme)**:
  - Toggleable Glass Theme (`BackdropFilter` translucent surfaces, 22px rounded corners, thin translucent white border, soft shadow, lime green accent `0xFF9ED756`, light gradient and dark navy-green gradient backgrounds) plus `System`, `Light`, and `Dark` theme modes.
  - Selective `BackdropFilter` usage (never wrapping the live camera preview) and instant disable option for slower devices.
- **Workout, Cardio, Warm-up & Mobility Logging**:
  - Cloud-synced Exercise Library with search, muscle group & equipment filters, coaching cues, instructions, and common mistakes.
  - Routine builder & template launcher, freestyle sessions, set-by-set logging (`standard`, `warmup`, `superset`, `drop_set`, `circuit`, `amrap`), quick weight/rep `+/-` steppers, RPE & RIR tracking, auto-starting Rest Timer with `+/- 15s` controls, mid-workout exercise swap, cardio interval logging, warm-up/cooldown/mobility modules, and offline-first queue with conflict-safe sync on reconnect.
- **Progress, Analytics, Periodisation & Coaching**:
  - Searchable session history with date & exercise filters, Epley estimated 1RM, best volume, weekly tonnage, sets per muscle group, custom responsive charts, consistency calendar, streaks, personal records (PRs), badges, multi-week periodisation builder, auto-progression & deload recommendations, and goal pace warnings.
- **Body, Health, Social, Content & Monetisation Modules**:
  - Body weight, body fat %, chest/waist/arms/thighs measurements, private progress photo comparison, macro/calorie targets, water/sleep/steps/resting HR logging, HR zones, honest wearable/equipment integration interfaces, opt-in social feed/challenges, trainer booking requests, and transparent subscription plan architecture.
- **Android Camera Object Detection (`camera` + `google_mlkit_object_detection`)**:
  - Capture-first detection (`CameraPreview` -> `takePicture()` -> `InputImage` -> `ObjectDetector` -> scaled bounding-box overlay -> save to `public.camera_detections`) plus optional throttled live stream mode (350ms throttle, single-frame lock, automatic stream stop before capture or on lifecycle pause/dispose).
  - Explicit safety & privacy disclosures; original camera photos are never uploaded unless explicit user consent is enabled in Settings (stored in private `camera-detections` bucket).

---

## 2. Folder Structure

```text
ai_gym_cloud/
  lib/
    main.dart
    app/
      app.dart
      routes.dart
    core/
      constants/
        app_config.dart
      localization/
        app_localizations.dart
      theme/
        glass_theme.dart
      widgets/
        glass_widgets.dart
      utils/
        validators.dart
        fitness_calculators.dart
    models/
      app_user.dart
      user_profile.dart
      exercise.dart
      routine.dart
      workout.dart
      workout_set.dart
      body_measurement.dart
      camera_detection.dart
      health_and_coaching_models.dart
    services/
      auth_service.dart
      database_service.dart
      camera_detection_service.dart
      notification_service.dart
      preference_service.dart
      diagnostics_service.dart
    repositories/
      profile_repository.dart
      exercise_repository.dart
      workout_repository.dart
      measurement_repository.dart
      detection_repository.dart
    screens/
      auth/
        auth_screen.dart
        otp_verification_screen.dart
        password_management_sheet.dart
      onboarding/
        onboarding_screen.dart
      dashboard/
        dashboard_screen.dart
      workout/
        workout_screen.dart
      exercise_library/
        exercise_library_screen.dart
      progress/
        progress_screen.dart
      body_health/
        body_health_screen.dart
      camera_detection/
        camera_detection_screen.dart
      settings/
        settings_screen.dart
      diagnostics/
        diagnostics_screen.dart
    widgets/
      rest_timer_banner.dart
      social_and_plans_sheet.dart
  supabase/
    schema.sql
    seed.sql
    storage_policies.sql
  test/
    app_test.dart
  pubspec.yaml
  analysis_options.yaml
  setup.ps1
  README.md
```

---

## 3. Flutter Prerequisites

1. **Flutter SDK**: Flutter `3.24+` / Dart `>=3.13.0 <4.0.0` (tested with Flutter `3.47.4` stable).
2. **Android Studio / Android SDK**: Android SDK Platform 34+, Android SDK Build-Tools, and USB Debugging enabled on your physical Android device.
3. **PowerShell**: Windows PowerShell 5.1+ or PowerShell 7+ to run `setup.ps1`.

---

## 4. Supabase Configuration & Security

- **Default Supabase Project URL**:
  `https://eprmvrtcpuydxhtzwfep.supabase.co`
- **How to Obtain the Publishable (Anon) Key**:
  1. Sign in to the [Supabase Dashboard](https://supabase.com/dashboard) and open project `eprmvrtcpuydxhtzwfep`.
  2. Navigate to **Project Settings** -> **API**.
  3. Under **Project API keys**, copy the `anon` / `public` (Publishable) key.
- **Why `service_role` Must NEVER Be Used in Flutter**:
  The `service_role` secret key bypasses all Row Level Security (RLS) policies and has full administrative read/write/delete privileges across every user's data. Any key compiled into a client APK can be extracted via reverse engineering. Never pass `service_role`, database passwords, or SMTP credentials to Flutter; always pass the `anon` Publishable Key via `--dart-define=SUPABASE_PUBLISHABLE_KEY=...` and enforce access control through PostgreSQL RLS policies.

### 4.1 Running the Database SQL Scripts

1. Open your Supabase project -> **SQL Editor** -> **New query**.
2. Paste and run `supabase/schema.sql` (creates all tables, foreign keys, indexes, RLS policies, the `on_auth_user_created` profile trigger, and default seed data).
3. Optionally run `supabase/seed.sql` (re-upserts default exercises, badges, and challenges) and `supabase/storage_policies.sql` (creates private `progress-photos` and `camera-detections` storage buckets with owner-folder RLS policies).

### 4.2 Enabling Email Provider & Confirm Email

1. Go to **Authentication** -> **Providers** -> **Email**.
2. Toggle **Enable Email provider** to **ON**.
3. Toggle **Confirm email** to **ON** so newly registered accounts must confirm their Email address.
4. Set **Mailer OTP Expiration** to `300` seconds (5 minutes) and **OTP Length** to `6` digits.

### 4.3 Configuring Supabase Email Templates

Go to **Authentication** -> **Email Templates** and configure the four templates below. Never display OTP tokens inside app popups or logs.

1. **Confirm Signup Template**:
   - **Subject**: `Confirm Your AI Gym Cloud Account`
   - **Body**:
     ```html
     <h2>Welcome to AI Gym Cloud</h2>
     <p>Click the link below to confirm your account email address:</p>
     <p><a href="{{ .ConfirmationURL }}">Confirm Email Address</a></p>
     <p>Or enter confirmation code: <strong>{{ .Token }}</strong></p>
     ```
2. **Magic Link / OTP Template (Used for Step-2 Login Email Code)**:
   - **Subject**: `AI Gym Login Verification`
   - **Body**:
     ```html
     <h2>AI Gym Login Verification</h2>
     <p>Your one-time login code is <strong>{{ .Token }}</strong>.</p>
     <p>If this was not requested, change the account password immediately.</p>
     ```
3. **Reset Password Template**:
   - **Subject**: `AI Gym Cloud Password Reset`
   - **Body**:
     ```html
     <h2>Password Reset Request</h2>
     <p>Use the link or code below to reset your AI Gym Cloud password:</p>
     <p><a href="{{ .ConfirmationURL }}">Reset Password</a></p>
     <p>Reset verification code: <strong>{{ .Token }}</strong></p>
     ```
4. **Email Change Template**:
   - **Subject**: `Confirm AI Gym Cloud Email Change`
   - **Body**:
     ```html
     <h2>Confirm Email Address Update</h2>
     <p>Click below to verify your new email address:</p>
     <p><a href="{{ .ConfirmationURL }}">Confirm Email Change</a></p>
     <p>Verification code: <strong>{{ .Token }}</strong></p>
     ```

---

## 5. Initializing the Project (`setup.ps1`)

Open PowerShell in the project folder and run:

```powershell
$env:PUB_CACHE="D:\FlutterPubCache"
Set-ExecutionPolicy -Scope Process Bypass
.\setup.ps1
```

`setup.ps1` automatically:
1. Backs up `lib/`, `test/`, `supabase/`, `pubspec.yaml`, `analysis_options.yaml`, and `README.md`.
2. Runs `flutter create . --platforms=android` to generate Android platform files.
3. Restores all project source files.
4. Injects `android.permission.CAMERA`, `android.permission.INTERNET`, and `<uses-feature android:name="android.hardware.camera" android:required="false" />` into `AndroidManifest.xml`.
5. Applies Gradle stability settings in `android/gradle.properties`.
6. Runs `flutter clean`, `flutter pub get`, `dart format lib test`, and `flutter analyze --no-fatal-infos`.

---

## 6. Running on an Android Device & Building APK

### Run on a Connected Physical Android Device

```powershell
flutter run -d DEVICE_ID `
  --dart-define=SUPABASE_URL=https://eprmvrtcpuydxhtzwfep.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY `
  --dart-define=ADMIN_EMAIL=YOUR_ADMIN_EMAIL
```

*(Note: If `SUPABASE_PUBLISHABLE_KEY` is omitted, the application safely displays a readable Configuration Error screen with copyable setup instructions.)*

### Run Static Analysis & Tests

```powershell
dart format lib test
flutter analyze --no-fatal-infos
flutter test
```

### Build a Debug APK

```powershell
flutter build apk --debug `
  --dart-define=SUPABASE_URL=https://eprmvrtcpuydxhtzwfep.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY `
  --dart-define=ADMIN_EMAIL=YOUR_ADMIN_EMAIL
```

---

## 7. User Guide: Registration, Login, Camera Detection & Admin Tools

### How to Register
1. Open the app and select the **Create Account** tab on the Auth screen.
2. Enter your **Display Name**, **Email**, **Password** (minimum 8 characters), and **Confirm Password**.
3. Tap **Create Account**. Check your Email inbox for the confirmation link before logging in.

### How to Log In (Email + Password + Email OTP)
1. Enter your registered **Email** and **Password** and tap **Sign In**.
2. Once credentials are validated, the app triggers `signInWithOtp(shouldCreateUser: false)` and transitions to the **6-Digit Email Verification** screen while keeping protected screens locked.
3. Open your Email inbox, read the 6-digit `{{ .Token }}` code, enter it into the verification screen, and tap **Verify & Enter App**.
4. First-time users are guided through the **Onboarding Profile Setup** screen.

### How to Use Camera Detection & Understand Limitations
1. Open the **Vision (Camera Detection)** tab in the bottom navigation bar.
2. Tap **Start Camera** and grant Android camera permission when prompted.
3. Point the camera at gym equipment or objects and tap **Capture & Detect** (or toggle **Throttled Live Stream** for 350ms single-frame throttled detection).
4. Review detected labels, confidence percentages, and scaled bounding boxes. Tap **Save to Supabase** on any detection to store metadata in `public.camera_detections`.
5. **Important Limitations**:
   - Performs general object detection only via Google ML Kit.
   - **Not medical advice**: does not diagnose injuries or guarantee exercise form/safety.
   - **Privacy**: does not identify any person or infer sensitive attributes. Saving raw images is disabled by default unless explicit consent is toggled in Settings.

### How to Use Admin Developer Tools
1. Launch the app with `--dart-define=ADMIN_EMAIL=your_verified_email@example.com`.
2. Log in with that exact Email, password, and verified 6-digit Email OTP (Guest accounts can never access Admin Tools).
3. Open **Settings** -> **Admin Developer Tools** to inspect FPS/UI build/raster estimates, build mode, Supabase Auth & DB read/write diagnostics, masked user/session IDs, Android hardware info (`device_info_plus`), camera/detector/sync status, and scrubbable runtime logs.
