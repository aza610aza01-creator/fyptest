import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/utils/validators.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/services/auth_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Step-2 Login Screen: Six-digit Email OTP verification (`verifyOTP` with `OtpType.email`).
/// Prevents access to protected screens until verified.
/// Never displays the OTP code inside the app, console, or popups.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.authService,
    required this.prefs,
  });

  final AuthService authService;
  final PreferenceService prefs;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _otpCtrl = TextEditingController();

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyCode(bool isZh) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.authService.verifyEmailOtpCode(
      otpCode: _otpCtrl.text,
      isZh: isZh,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, widget.prefs.languageCode);
    final isZh = strings.isZh;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('otp_title')),
        actions: [
          TextButton.icon(
            onPressed: () {
              widget.prefs.setLanguageCode(isZh ? 'en' : 'zh');
            },
            icon: const Icon(Icons.language),
            label: Text(isZh ? 'EN' : '繁中'),
          ),
        ],
      ),
      body: GlassScaffoldBackground(
        glassEnabled: widget.prefs.glassThemeEnabled,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ListenableBuilder(
                  listenable: widget.authService,
                  builder: (context, _) {
                    final maskedEmail = AppConfig.maskEmail(
                      widget.authService.pendingOtpEmail,
                    );
                    final cooldown = widget.authService.resendCooldownSeconds;

                    return GlassPanel(
                      glassEnabled: widget.prefs.glassThemeEnabled,
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.mark_email_read_outlined,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              strings.tr('otp_title'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${strings.tr('otp_subtitle')}
Email: $maskedEmail',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            if (widget.authService.errorMessage != null)
                              ErrorBannerCard(
                                message: widget.authService.errorMessage!,
                              ),
                            if (widget.authService.statusMessage != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.7),
                                ),
                                child: Text(
                                  widget.authService.statusMessage!,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            TextFormField(
                              key: const Key('otp_code_input'),
                              controller: _otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                letterSpacing: 8,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: InputDecoration(
                                labelText: strings.tr('otp_input_label'),
                                hintText: '000000',
                                prefixIcon: const Icon(Icons.pin_outlined),
                              ),
                              validator: (v) =>
                                  Validators.validateOtpCode(v, isZh: isZh),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              key: const Key('verify_otp_button'),
                              onPressed: widget.authService.isLoading
                                  ? null
                                  : () => _verifyCode(isZh),
                              icon: widget.authService.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.verified_user_outlined),
                              label: Text(strings.tr('verify_otp')),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: widget.authService.canResendOtp
                                  ? () => widget.authService.resendEmailOtp(
                                        isZh: isZh,
                                      )
                                  : null,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                cooldown > 0
                                    ? '${strings.tr('resend_wait')} ${cooldown}s'
                                    : strings.tr('resend_code'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: widget.authService.cancelOtpLogin,
                                  icon: const Icon(Icons.alternate_email),
                                  label: Text(strings.tr('change_email')),
                                ),
                                TextButton.icon(
                                  onPressed: widget.authService.cancelOtpLogin,
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: Text(strings.tr('cancel_login')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
