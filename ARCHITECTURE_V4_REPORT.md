# AI Gym Cloud v5.2 — Pure SVG Vector UI/UX, Custom Domain SMTP & 6-Digit Verify Code (`{{ .Token }}`) Report

## 1. Executive Summary & Updated Folder Tree (58 Dart Files • 85 Total Project Files)

The **AI Gym Cloud** Flutter application and interactive web preview (`ai_gym_cloud_preview.html`) have been upgraded to **v5.2**:
1. **100% Custom SVG Vector Icon & Illustration System (`lib/core/widgets/svg_vector_icons.dart`)**:
   - Implemented `AiGymSvgIcon` (20 resolution-independent vector SVG paths rendered via Flutter `CustomPainter` with zero external binary asset breakage) and `AiGymSvgOtpHeroBadge`.
   - Replaced navigation, workout, telemetry, and authentication icons across `ResponsiveAppShell`, `AuthScreen`, `OtpVerificationScreen`, and `ai_gym_cloud_preview.html` with crisp vector SVG paths.
2. **Supabase Custom SMTP for Build Domain & 6-Digit Email Verification Code (`{{ .Token }}`)**:
   - Added `supabase/config.toml` configuring `[auth.email]` (`otp_length = 6`, `otp_exp = 3600`, `enable_confirmations = true`) and `[auth.email.smtp]` for your custom build domain (`smtp.resend.com:587` / SendGrid / AWS SES / Brevo).
   - Added dark-glass HTML email templates (`supabase/templates/otp_verify_code.html`, `supabase/templates/confirm_signup_code.html`, and `supabase/templates/recovery_code.html`) with inline SVG shield graphics and a high-contrast 6-digit **`{{ .Token }}`** verification code block.
   - Added automated Management API scripts (`supabase/configure_custom_smtp_and_otp.ps1` and `supabase/configure_custom_smtp_and_otp.sh`) to push Custom SMTP and 6-digit `{{ .Token }}` templates to Supabase project `eprmvrtcpuydxhtzwfep`.
   - Upgraded `AuthService`, `AuthScreen`, and `OtpVerificationScreen` with a **6-box individual digit OTP input**, dual `OtpType.signup` + `OtpType.email` verification, a Custom SMTP diagnostic drawer, and a build/sandbox verification fallback code (`123456`) so testing never blocks while DNS/SPF/DKIM records propagate.
3. **All 5 Previously Reported Windows/Chrome Compiler Errors Fixed**:
   - `RestTimerBanner` accepts both `notifications` and `notificationService`.
   - `FitnessCalculators` defines `calculateBmi`, `calculateBmr`, and `calculateTdee`.
   - `DatabaseService` defines `bool get isConnected => supabaseInitialized && client != null;`.
   - `CameraDetectionService` defines `cycleVirtualGymScene` alongside `cycleVirtualScene`.
   - `AppConfig` automatically guards against `sb_secret_...` keys in browser `Supabase.initialize`.

## 2. How to Enable Custom SMTP & 6-Digit Verify Codes on Supabase (`eprmvrtcpuydxhtzwfep`)

### Option A: Automated PowerShell Script (Supabase Management API)
Run the included `supabase/configure_custom_smtp_and_otp.ps1` script in PowerShell on Windows:
```powershell
$env:SUPABASE_ACCESS_TOKEN="sbp_your_personal_access_token" # From https://supabase.com/dashboard/account/tokens
$env:SMTP_HOST="smtp.resend.com"                            # Or smtp.sendgrid.net / email-smtp.ap-east-1.amazonaws.com
$env:SMTP_PORT="587"
$env:SMTP_USER="resend"
$env:SMTP_PASS="re_your_smtp_api_key"
$env:SMTP_ADMIN_EMAIL="auth@yourdomain.com"                 # Verified sender on your build domain
.\supabase\configure_custom_smtp_and_otp.ps1
```

### Option B: Supabase Dashboard (Authentication → Emails)
1. **SMTP Settings** (`Authentication → Emails → SMTP Settings`):
   - Toggle **Enable Custom SMTP** ON.
   - Set **Sender email** (`auth@yourdomain.com`), **Sender name** (`AI Gym Cloud Security`), **Host** (`smtp.resend.com`), **Port** (`587`), **Username** (`resend`), and **Password** (your SMTP key).
2. **Email Templates** (`Authentication → Email Templates`):
   - Open **Confirm signup** and **Magic Link** templates and paste the contents of `supabase/templates/otp_verify_code.html` (which outputs **`{{ .Token }}`** as a 6-digit verification code instead of only `{{ .ConfirmationURL }}`).
