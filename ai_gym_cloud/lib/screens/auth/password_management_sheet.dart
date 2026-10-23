import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/utils/validators.dart';
import 'package:ai_gym_flutter/services/auth_service.dart';

/// Modal sheet for Forgot Password (reset email) and Authenticated Change Password.
class PasswordManagementSheet extends StatefulWidget {
  const PasswordManagementSheet({
    super.key,
    required this.authService,
    required this.isZh,
    required this.isAuthenticatedChangeMode,
    this.initialEmail = '',
  });

  final AuthService authService;
  final bool isZh;
  final bool isAuthenticatedChangeMode;
  final String initialEmail;

  @override
  State<PasswordManagementSheet> createState() =>
      _PasswordManagementSheetState();
}

class _PasswordManagementSheetState extends State<PasswordManagementSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final isZh = widget.isZh;

    if (widget.isAuthenticatedChangeMode) {
      final ok = await widget.authService.changePassword(
        newPassword: _newPasswordCtrl.text,
        isZh: isZh,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      }
    } else {
      final ok = await widget.authService.sendPasswordResetEmail(
        email: _emailCtrl.text,
        isZh: isZh,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isZh = widget.isZh;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.isAuthenticatedChangeMode
                      ? (isZh ? '變更帳戶密碼' : 'Change Account Password')
                      : (isZh ? '重設忘記密碼' : 'Reset Forgotten Password'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                if (!widget.isAuthenticatedChangeMode)
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: isZh ? '註冊 Email 地址' : 'Account Email Address',
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (v) => Validators.validateEmail(v, isZh: isZh),
                  )
                else ...[
                  TextFormField(
                    controller: _newPasswordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: isZh ? '新密碼（至少 8 個字元）' : 'New Password (min 8 chars)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        Validators.validatePassword(v, isZh: isZh),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: isZh ? '確認新密碼' : 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_reset),
                    ),
                    validator: (v) => Validators.validateConfirmPassword(
                      _newPasswordCtrl.text,
                      v,
                      isZh: isZh,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ListenableBuilder(
                  listenable: widget.authService,
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.authService.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              widget.authService.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        FilledButton.icon(
                          onPressed:
                              widget.authService.isLoading ? null : _submit,
                          icon: widget.authService.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            widget.isAuthenticatedChangeMode
                                ? (isZh ? '更新密碼' : 'Update Password')
                                : (isZh
                                    ? '發送重設密碼 Email'
                                    : 'Send Password Reset Email'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
