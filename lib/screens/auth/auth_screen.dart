import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/utils/validators.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/screens/auth/password_management_sheet.dart';
import 'package:ai_gym_flutter/services/auth_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Authentication screen supporting:
/// - Readable Configuration Error banner when SUPABASE_PUBLISHABLE_KEY is missing
/// - Sign In (Email + Password -> triggers Step-2 Email OTP)
/// - Registration (Display Name, Email, Password, Confirm Password, visibility toggle,
///   password requirements, Create Account button, Link back to Login)
/// - Forgot Password & Guest Mode entry
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

  late bool _isRegisterMode;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isRegisterMode = widget.initialRegisterMode;
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
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
      final success = await widget.authService.registerAccount(
        displayName: _displayNameCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        isZh: isZh,
      );
      if (!mounted) return;
      if (success) {
        _passwordCtrl.clear();
        _confirmPasswordCtrl.clear();
        setState(() {
          _isRegisterMode = false;
        });
      }
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

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('app_title')),
        actions: [
          IconButton(
            tooltip: strings.tr('glass_theme_label'),
            onPressed: () => widget.prefs.setGlassThemeEnabled(!glass),
            icon: Icon(glass ? Icons.blur_on : Icons.blur_off),
          ),
          TextButton.icon(
            key: const Key('auth_language_toggle'),
            onPressed: () =>
                widget.prefs.setLanguageCode(isZh ? 'en' : 'zh'),
            icon: const Icon(Icons.translate),
            label: Text(isZh ? 'English' : '繁體中文'),
          ),
        ],
      ),
      body: GlassScaffoldBackground(
        glassEnabled: glass,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.config.isConfigured)
                      GlassPanel(
                        glassEnabled: glass,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    strings.tr('config_error_title'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(strings.tr('config_error_subtitle')),
                            const SizedBox(height: 6),
                            SelectableText(
                              'flutter run --dart-define=SUPABASE_URL=${widget.config.supabaseUrl} '
                              '--dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY '
                              '--dart-define=ADMIN_EMAIL=YOUR_ADMIN_EMAIL',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    GlassPanel(
                      glassEnabled: glass,
                      padding: const EdgeInsets.all(22),
                      child: ListenableBuilder(
                        listenable: widget.authService,
                        builder: (context, _) {
                          return Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SegmentedButton<bool>(
                                  segments: [
                                    ButtonSegment<bool>(
                                      value: false,
                                      label: Text(strings.tr('login_tab')),
                                      icon: const Icon(Icons.login),
                                    ),
                                    ButtonSegment<bool>(
                                      value: true,
                                      label: Text(strings.tr('register_tab')),
                                      icon: const Icon(Icons.person_add_alt_1),
                                    ),
                                  ],
                                  selected: {_isRegisterMode},
                                  onSelectionChanged: (sel) =>
                                      _toggleAuthMode(sel.first),
                                ),
                                const SizedBox(height: 18),
                                if (widget.authService.errorMessage != null)
                                  ErrorBannerCard(
                                    message: widget.authService.errorMessage!,
                                  ),
                                if (widget.authService.statusMessage != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.78),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      widget.authService.statusMessage!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (_isRegisterMode) ...[
                                  TextFormField(
                                    key: const Key('register_display_name'),
                                    controller: _displayNameCtrl,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: strings.tr('display_name'),
                                      prefixIcon:
                                          const Icon(Icons.badge_outlined),
                                    ),
                                    validator: (v) =>
                                        Validators.validateDisplayName(
                                      v,
                                      isZh: isZh,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextFormField(
                                  key: const Key('auth_email_field'),
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: strings.tr('email'),
                                    prefixIcon:
                                        const Icon(Icons.email_outlined),
                                  ),
                                  validator: (v) =>
                                      Validators.validateEmail(v, isZh: isZh),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: const Key('auth_password_field'),
                                  controller: _passwordCtrl,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: strings.tr('password'),
                                    prefixIcon:
                                        const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: isZh ? '顯示/隱藏密碼' : 'Toggle Password Visibility',
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (v) => Validators.validatePassword(
                                    v,
                                    isZh: isZh,
                                  ),
                                ),
                                if (_isRegisterMode) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    strings.tr('password_requirements'),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    key: const Key('register_confirm_password'),
                                    controller: _confirmPasswordCtrl,
                                    obscureText: _obscurePassword,
                                    decoration: InputDecoration(
                                      labelText:
                                          strings.tr('confirm_password'),
                                      prefixIcon:
                                          const Icon(Icons.verified_outlined),
                                    ),
                                    validator: (v) =>
                                        Validators.validateConfirmPassword(
                                      _passwordCtrl.text,
                                      v,
                                      isZh: isZh,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  key: const Key('auth_submit_button'),
                                  onPressed: widget.authService.isLoading
                                      ? null
                                      : () => _submitForm(isZh),
                                  icon: widget.authService.isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          _isRegisterMode
                                              ? Icons.person_add
                                              : Icons.arrow_forward,
                                        ),
                                  label: Text(
                                    _isRegisterMode
                                        ? strings.tr('create_account')
                                        : strings.tr('sign_in'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_isRegisterMode)
                                  TextButton(
                                    onPressed: () => _toggleAuthMode(false),
                                    child: Text(strings.tr('back_to_login')),
                                  )
                                else
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          _openForgotPasswordSheet(isZh),
                                      child:
                                          Text(strings.tr('forgot_password')),
                                    ),
                                  ),
                                const Divider(height: 24),
                                OutlinedButton.icon(
                                  key: const Key('enter_guest_mode_button'),
                                  onPressed: widget.authService.enterGuestMode,
                                  icon: const Icon(Icons.offline_bolt_outlined),
                                  label: Text(strings.tr('continue_guest')),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
