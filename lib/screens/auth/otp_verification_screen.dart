import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/utils/validators.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/core/widgets/svg_vector_icons.dart';
import 'package:ai_gym_flutter/services/auth_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Step-2 Login & Registration Verification Screen:
/// Six-digit Email OTP verification (`verifyOTP` with `OtpType.email` / `OtpType.signup`)
/// + Custom SMTP Build Domain Diagnostics Drawer.
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

  void _openCustomSmtpDiagnosticsSheet(BuildContext context, bool isZh) {
    final smtp = widget.authService.smtpConfig;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const AiGymSvgIcon(
                      AiGymSvgIconName.smtpServer,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isZh
                            ? 'Supabase 自訂域名 SMTP 與 6 位數驗證碼設定'
                            : 'Supabase Custom Domain SMTP & 6-Digit Verify Code',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isZh
                      ? '專案已內建 supabase/config.toml 與 .\supabase\configure_custom_smtp_and_otp.ps1 自動化腳本，將確認信與登入信模板改為發送 6 位數 {{ .Token }} 驗證碼：'
                      : 'Included in supabase/config.toml and .\\supabase\\configure_custom_smtp_and_otp.ps1 to enable Custom SMTP for your build domain and output 6-digit {{ .Token }} codes:',
                  style: const TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: SelectableText(
                    'Build Domain : ${smtp.buildDomain}\n'
                    'SMTP Server  : ${smtp.smtpHost}:${smtp.smtpPort}\n'
                    'Sender Email : ${smtp.senderEmail}\n'
                    'OTP Template : {{ .Token }} (${smtp.otpLength} digits, ${smtp.otpExpirySeconds}s expiry)\n'
                    'CLI Script   : .\\supabase\\configure_custom_smtp_and_otp.ps1',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          IconButton(
            tooltip: 'Custom SMTP & 6-Digit Verify Code Info',
            onPressed: () => _openCustomSmtpDiagnosticsSheet(context, isZh),
            icon: const AiGymSvgIcon(AiGymSvgIconName.smtpServer, size: 20),
          ),
          TextButton.icon(
            onPressed: () {
              widget.prefs.setLanguageCode(isZh ? 'en' : 'zh');
            },
            icon: const AiGymSvgIcon(AiGymSvgIconName.domainGlobe, size: 18),
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
                            Center(
                              child: AiGymSvgOtpHeroBadge(
                                primaryColor:
                                    Theme.of(context).colorScheme.primary,
                                secondaryColor:
                                    Theme.of(context).colorScheme.secondary,
                                size: 72,
                              ),
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
                              '${strings.tr('otp_subtitle')}\nEmail: $maskedEmail',
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
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: AiGymSvgIcon(
                                    AiGymSvgIconName.keyToken,
                                    size: 18,
                                  ),
                                ),
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
                                  : const AiGymSvgIcon(
                                      AiGymSvgIconName.checkVerified,
                                      size: 18,
                                    ),
                              label: Text(strings.tr('verify_otp')),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: widget.authService.canResendOtp
                                  ? () => widget.authService.resendEmailOtp(
                                        isZh: isZh,
                                      )
                                  : null,
                              icon: const AiGymSvgIcon(
                                AiGymSvgIconName.mailCode,
                                size: 17,
                              ),
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
                                  onPressed: () =>
                                      _openCustomSmtpDiagnosticsSheet(
                                    context,
                                    isZh,
                                  ),
                                  icon: const AiGymSvgIcon(
                                    AiGymSvgIconName.smtpServer,
                                    size: 16,
                                  ),
                                  label: Text(
                                    isZh ? '自訂 SMTP 設定' : 'Custom SMTP Info',
                                  ),
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
