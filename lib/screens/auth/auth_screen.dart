import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/utils/validators.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/core/widgets/svg_vector_icons.dart';
import 'package:ai_gym_flutter/screens/auth/password_management_sheet.dart';
import 'package:ai_gym_flutter/services/auth_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Implements Reference Format Screen #1 ("Hello!" Welcome Splash with Teardrop
/// Personal Trainer Emblem & Dual Pill Buttons) and Screen #2 (Segmented Pill
/// Toggle `Log in | Sign up` + Underline Inputs + Centered Pill CTA).
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.config,
    required this.authService,
    required this.prefs,
    this.initialRegisterMode = false,
  });

  final AppConfig config;
  final AuthService authService;
  final PreferenceService prefs;
  final bool initialRegisterMode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  bool _showWelcomeSplash = true;
  late bool _isRegisterMode;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isRegisterMode = widget.initialRegisterMode;
    if (widget.initialRegisterMode) {
      _showWelcomeSplash = false;
    }
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _openAuthForm({required bool registerMode}) {
    widget.authService.clearMessages();
    setState(() {
      _showWelcomeSplash = false;
      _isRegisterMode = registerMode;
    });
  }

  void _toggleAuthMode(bool registerMode) {
    widget.authService.clearMessages();
    setState(() {
      _isRegisterMode = registerMode;
    });
  }

  Future<void> _submitForm(bool isZh) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isRegisterMode) {
      await widget.authService.registerAccount(
        displayName: _displayNameCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        isZh: isZh,
      );
    } else {
      await widget.authService.signInWithPasswordAndRequestOtp(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        isZh: isZh,
      );
    }
  }

  void _openForgotPasswordSheet(bool isZh) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PasswordManagementSheet(
        authService: widget.authService,
        isZh: isZh,
        isAuthenticatedChangeMode: false,
        initialEmail: _emailCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, widget.prefs.languageCode);
    final isZh = strings.isZh;
    final glass = widget.prefs.glassThemeEnabled;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: widget.authService,
      builder: (context, _) {
        final busy = widget.authService.isLoading;
        final err = widget.authService.errorMessage;
        final info = widget.authService.statusMessage;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 412),
                  child: _showWelcomeSplash
                      ? _buildScreen1WelcomeSplash(context, isZh, scheme, busy)
                      : _buildScreen2SegmentedAuthForm(
                          context,
                          strings,
                          isZh,
                          glass,
                          scheme,
                          busy,
                          err,
                          info,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Screen #1 Format: "Hello!", Teardrop Personal Trainer Emblem,
  /// "Welcome to your personal trainer", and dual pill buttons (Sign Up | Log In).
  Widget _buildScreen1WelcomeSplash(
    BuildContext context,
    bool isZh,
    ColorScheme scheme,
    bool busy,
  ) {
    return GlassPanel(
      glassEnabled: widget.prefs.glassThemeEnabled,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('auth_language_toggle'),
                onPressed: () {
                  final next = isZh ? 'en' : 'zh';
                  widget.prefs.setLanguageCode(next);
                },
                child: Text(isZh ? 'EN' : '繁中'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isZh ? 'Hello! 您好' : 'Hello!',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 28),
          // Teardrop / Circle Personal Trainer Emblem (Reference Screen #1)
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(68),
                topRight: Radius.circular(68),
                bottomLeft: Radius.circular(68),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: scheme.primary, width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AiGymSvgIcon(AiGymSvgIconName.workoutDumbbell, size: 48, color: scheme.primary),
                const SizedBox(height: 6),
                Text(
                  'AI TRAINER',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            isZh ? '歡迎使用您的專屬 AI 個人教練' : 'Welcome to your\npersonal trainer',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: scheme.onSurface.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 36),
          if (!widget.config.isConfigured) ...[
            Text(
              isZh
                  ? '需要設定 Supabase：請以 --dart-define 傳入 SUPABASE_URL 與 SUPABASE_PUBLISHABLE_KEY。'
                  : 'Supabase Configuration Required. Pass SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY via --dart-define.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.error,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('welcome_signup_pill_button'),
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: busy ? null : () => _openAuthForm(registerMode: true),
                  child: Text(
                    isZh ? '註冊 Sign Up' : 'Sign Up',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: OutlinedButton(
                  key: const Key('welcome_login_pill_button'),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: busy ? null : () => _openAuthForm(registerMode: false),
                  child: Text(
                    isZh ? '登入 Log In' : 'Log In',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            key: const Key('auth_guest_mode_button'),
            onPressed: busy
                ? null
                : () => widget.authService.continueAsGuest(isZh: isZh),
            icon: const Icon(Icons.explore_outlined, size: 17),
            label: Text(
              isZh ? '以訪客模式預覽 12 個畫面' : 'Preview as Guest (12-Screen UI)',
            ),
          ),
        ],
      ),
    );
  }

  /// Screen #2 Format: Rounded Segmented Pill Toggle (`Log in` | `Sign up`),
  /// bottom-bordered underline inputs, centered pill button, and `Forgot your password?`.
  Widget _buildScreen2SegmentedAuthForm(
    BuildContext context,
    AppStrings strings,
    bool isZh,
    bool glass,
    ColorScheme scheme,
    bool busy,
    String? err,
    String? info,
  ) {
    return GlassPanel(
      glassEnabled: glass,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(() => _showWelcomeSplash = true),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  tooltip: isZh ? '返回歡迎頁' : 'Back to Welcome',
                ),
                TextButton(
                  key: const Key('auth_language_toggle'),
                  onPressed: () {
                    final next = isZh ? 'en' : 'zh';
                    widget.prefs.setLanguageCode(next);
                  },
                  child: Text(isZh ? 'EN' : '繁中'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Segmented Pill Toggle (`Log in` | `Sign up`) matching Reference Screen #2
            Container(
              height: 46,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.45), width: 1.4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: busy ? null : () => _toggleAuthMode(false),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !_isRegisterMode ? scheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isZh ? '登入 Log in' : 'Log in',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: !_isRegisterMode
                                ? scheme.onPrimary
                                : scheme.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: busy ? null : () => _toggleAuthMode(true),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isRegisterMode ? scheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isZh ? '註冊 Sign up' : 'Sign up',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _isRegisterMode
                                ? scheme.onPrimary
                                : scheme.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (_isRegisterMode) ...[
              TextFormField(
                key: const Key('auth_display_name_field'),
                controller: _displayNameCtrl,
                decoration: InputDecoration(
                  labelText: isZh ? '姓名 Full Name' : 'Full Name',
                  border: const UnderlineInputBorder(),
                ),
                validator: (v) => Validators.validateDisplayName(v, isZh: isZh),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              key: const Key('auth_email_field'),
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: isZh ? '電郵或電話 Email / Phone' : 'Email or +3 (345) 478-39-48',
                border: const UnderlineInputBorder(),
              ),
              validator: (v) => Validators.validateEmail(v, isZh: isZh),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('auth_password_field'),
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: strings.tr('password'),
                border: const UnderlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: (v) => Validators.validatePassword(v, isZh: isZh),
            ),
            if (_isRegisterMode) ...[
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('auth_confirm_password_field'),
                controller: _confirmPasswordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: strings.tr('confirm_password'),
                  border: const UnderlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v != _passwordCtrl.text) {
                    return isZh ? '兩次輸入的密碼不一致' : 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
            if (err != null) ...[
              const SizedBox(height: 12),
              Text(
                err,
                style: const TextStyle(
                  color: Color(0xFFFF453A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (info != null) ...[
              const SizedBox(height: 12),
              Text(
                info,
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 26),
            SizedBox(
              width: 210,
              height: 44,
              child: FilledButton(
                key: const Key('auth_submit_button'),
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                ),
                onPressed: busy ? null : () => _submitForm(isZh),
                child: Text(
                  _isRegisterMode
                      ? (isZh ? '註冊 Sign up' : 'Sign up')
                      : (isZh ? '登入 Log in' : 'Log in'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              key: const Key('auth_forgot_password_button'),
              onPressed: busy ? null : () => _openForgotPasswordSheet(isZh),
              child: Text(
                isZh ? '忘記密碼？ Forgot your password?' : 'Forgot your password?',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: busy
                  ? null
                  : () => widget.authService.continueAsGuest(isZh: isZh),
              child: Text(
                isZh ? '先以訪客身分體驗 >' : 'Continue as Guest >',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
