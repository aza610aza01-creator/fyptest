import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';

/// Implements all Section 3 account flows:
/// - Registration with display_name metadata & email confirmation
/// - Two-step Login: Email + Password check -> Email OTP (`signInWithOtp`) ->
///   6-digit `verifyOTP(type: OtpType.email)` before granting app access
/// - Resend OTP countdown, Change Email, Cancel Login
/// - Forgot Password, Reset Password Email, Change Password, Single/Global Logout
/// - Guest Mode & Upgrade Guest Account
/// - Verified Admin (`ADMIN_EMAIL`) role evaluation
class AuthService extends ChangeNotifier {
  AuthService({
    required this.config,
    required this.diagnostics,
    required this.supabaseInitialized,
  }) {
    _initializeAuthState();
  }

  final AppConfig config;
  final DiagnosticsService diagnostics;
  final bool supabaseInitialized;

  AppUser _currentUser = AppUser.unauthenticated();
  String _pendingOtpEmail = '';
  String _pendingDisplayName = '';
  int _resendCooldownSeconds = 0;
  Timer? _resendTimer;
  bool _isLoading = false;
  String? _errorMessage;
  String? _statusMessage;

  AppUser get currentUser => _currentUser;
  String get pendingOtpEmail => _pendingOtpEmail;
  int get resendCooldownSeconds => _resendCooldownSeconds;
  bool get canResendOtp => _resendCooldownSeconds <= 0 && !_isLoading;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;

  SupabaseClient? get _client =>
      supabaseInitialized ? Supabase.instance.client : null;

  void _initializeAuthState() {
    if (!supabaseInitialized) {
      diagnostics.logEvent('Supabase not initialized (missing publishable key).');
      return;
    }
    // Always require explicit 2-step OTP verification during login session
    final session = _client?.auth.currentSession;
    if (session != null) {
      // Clear stale unverified session on cold boot so two-step OTP is enforced
      unawaited(_client?.auth.signOut());
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();
  }

  /// 3.1 Registration flow
  Future<bool> registerAccount({
    required String displayName,
    required String email,
    required String password,
    required bool isZh,
  }) async {
    if (!supabaseInitialized || _client == null) {
      _errorMessage = isZh
          ? '尚未設定 SUPABASE_PUBLISHABLE_KEY，無法建立雲端帳戶。'
          : 'Supabase is not configured. Provide SUPABASE_PUBLISHABLE_KEY first.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final cleanEmail = email.trim();
      final cleanName = displayName.trim();

      await _client!.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'display_name': cleanName},
      );

      // Ensure user is not signed in before confirming email & completing 2FA
      await _client!.auth.signOut();

      diagnostics.logEvent(
        'Registration requested for ${AppConfig.maskEmail(cleanEmail)}',
      );
      _statusMessage = isZh
          ? '註冊成功！系統已發送確認信至您的 Email 收件匣，請先點擊信中連結完成驗證後再登入。'
          : 'Registration submitted! Please check your Email inbox to confirm your account before logging in.';
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      diagnostics.logEvent('AuthException during registration: ${e.statusCode}');
    } catch (_) {
      _errorMessage = isZh
          ? '網路或伺服器連線失敗，請稍後再試。'
          : 'Network error during registration. Please try again.';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 3.2 Login Step 1: Verify Email + Password, lock protected screens,
  /// and trigger Email OTP via `signInWithOtp(shouldCreateUser: false)`.
  Future<bool> signInWithPasswordAndRequestOtp({
    required String email,
    required String password,
    required bool isZh,
  }) async {
    if (!supabaseInitialized || _client == null) {
      _errorMessage = isZh
          ? '尚未設定 SUPABASE_PUBLISHABLE_KEY，請先完成設定或使用訪客模式。'
          : 'Supabase Publishable Key is missing. Configure --dart-define or use Guest Mode.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    final cleanEmail = email.trim();
    try {
      // Step 1: Validate Email and password credentials
      final response = await _client!.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        _errorMessage = isZh ? '登入失敗，請檢查帳號與密碼。' : 'Invalid login credentials.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _pendingDisplayName =
          (user.userMetadata?['display_name'] ?? cleanEmail.split('@').first)
              .toString();

      // Step 2: Sign out immediately to prevent access to protected screens
      // until the second-factor Email OTP is verified.
      await _client!.auth.signOut();

      // Step 3: Send the 6-digit Email OTP
      await _client!.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: false,
      );

      _pendingOtpEmail = cleanEmail;
      _currentUser = AppUser(
        id: user.id,
        email: cleanEmail,
        displayName: _pendingDisplayName,
        stage: AuthFlowStage.awaitingEmailOtp,
        isAdmin: false,
      );
      _startResendCooldown(60);
      _statusMessage = isZh
          ? '密碼驗證通過！已發送 6 位數驗證碼至您的 Email 收件匣。'
          : 'Password verified! A 6-digit login code has been sent to your Email inbox.';
      diagnostics.logEvent(
        'Password verified & Email OTP dispatched for ${AppConfig.maskEmail(cleanEmail)}',
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      diagnostics.logEvent('AuthException during login step 1: ${e.statusCode}');
    } catch (_) {
      _errorMessage = isZh
          ? '連線失敗，請檢查網路狀態後重試。'
          : 'Unable to reach authentication server. Check your connection.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 3.2 Login Step 2: Verify the 6-digit Email OTP using `OtpType.email`.
  Future<bool> verifyEmailOtpCode({
    required String otpCode,
    required bool isZh,
  }) async {
    if (!supabaseInitialized || _client == null || _pendingOtpEmail.isEmpty) {
      _errorMessage = isZh ? '驗證工作階段無效，請重新登入。' : 'Invalid OTP session. Please sign in again.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _client!.auth.verifyOTP(
        email: _pendingOtpEmail,
        token: otpCode.trim(),
        type: OtpType.email,
      );

      final verifiedUser = res.user ?? _client!.auth.currentUser;
      if (verifiedUser == null) {
        _errorMessage = isZh ? '驗證碼無效或已過期。' : 'OTP verification failed or expired.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final verifiedEmail = verifiedUser.email ?? _pendingOtpEmail;
      final isAdmin = config.isAdminEmail(
        verifiedEmail,
        isOtpVerified: true,
        isGuest: false,
      );
      final metaName = verifiedUser.userMetadata?['display_name']?.toString();

      _currentUser = AppUser(
        id: verifiedUser.id,
        email: verifiedEmail,
        displayName: (metaName != null && metaName.trim().isNotEmpty)
            ? metaName
            : (_pendingDisplayName.isNotEmpty
                ? _pendingDisplayName
                : verifiedEmail.split('@').first),
        stage: AuthFlowStage.authenticated,
        isAdmin: isAdmin,
      );
      _pendingOtpEmail = '';
      _resendTimer?.cancel();
      _resendCooldownSeconds = 0;
      _statusMessage = null;
      diagnostics.logEvent(
        'Email OTP verified for ${AppConfig.maskEmail(verifiedEmail)} (admin=$isAdmin)',
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      diagnostics.logEvent('AuthException during OTP verify: ${e.statusCode}');
    } catch (_) {
      _errorMessage = isZh
          ? 'OTP 驗證失敗，請檢查網路或重新發送驗證碼。'
          : 'Failed to verify OTP code. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Resends the 6-digit Email OTP with a 60-second cooldown timer.
  Future<void> resendEmailOtp({required bool isZh}) async {
    if (!canResendOtp || _client == null || _pendingOtpEmail.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client!.auth.signInWithOtp(
        email: _pendingOtpEmail,
        shouldCreateUser: false,
      );
      _startResendCooldown(60);
      _statusMessage = isZh
          ? '已重新發送 6 位數驗證碼至您的 Email。'
          : 'A new 6-digit code has been sent to your Email.';
      diagnostics.logEvent(
        'Resent Email OTP to ${AppConfig.maskEmail(_pendingOtpEmail)}',
      );
    } on AuthException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = isZh ? '重新發送失敗，請稍後再試。' : 'Could not resend code.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Cancels pending OTP login and returns to Email/password screen.
  Future<void> cancelOtpLogin() async {
    _resendTimer?.cancel();
    _resendCooldownSeconds = 0;
    _pendingOtpEmail = '';
    _errorMessage = null;
    _statusMessage = null;
    if (_client != null) {
      try {
        await _client!.auth.signOut();
      } catch (_) {}
    }
    _currentUser = AppUser.unauthenticated();
    notifyListeners();
  }

  /// 3.3 Password Management: Send Password Reset Email
  Future<bool> sendPasswordResetEmail({
    required String email,
    required bool isZh,
  }) async {
    if (!supabaseInitialized || _client == null) {
      _errorMessage = isZh ? 'Supabase 未設定。' : 'Supabase is not configured.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      await _client!.auth.resetPasswordForEmail(email.trim());
      _statusMessage = isZh
          ? '已發送密碼重設信至 ${AppConfig.maskEmail(email)}，請檢查收件匣。'
          : 'Password reset Email sent to ${AppConfig.maskEmail(email)}.';
      diagnostics.logEvent('Password reset requested for ${AppConfig.maskEmail(email)}');
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = isZh ? '無法發送重設信，請稍後再試。' : 'Failed to send reset Email.';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 3.3 Change Password for an authenticated non-guest account
  Future<bool> changePassword({
    required String newPassword,
    required bool isZh,
  }) async {
    if (_currentUser.isGuest || ! _currentUser.isFullyAuthenticated || _client == null) {
      _errorMessage = isZh
          ? '訪客或未驗證帳戶無法變更雲端密碼。'
          : 'Only authenticated cloud accounts can change their password.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      await _client!.auth.updateUser(UserAttributes(password: newPassword));
      _statusMessage = isZh ? '密碼已成功更新！' : 'Password updated successfully!';
      diagnostics.logEvent('Password changed for authenticated user.');
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = isZh ? '更新密碼失敗，請稍後再試。' : 'Failed to update password.';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 3.4 Guest Mode entry (strictly local-only, never admin)
  void enterGuestMode() {
    _resendTimer?.cancel();
    _pendingOtpEmail = '';
    _errorMessage = null;
    _statusMessage = null;
    _currentUser = AppUser.guest();
    diagnostics.logEvent('Entered local-only Guest Mode.');
    notifyListeners();
  }

  /// Leaves Guest Mode or logs out from current or all sessions.
  Future<void> signOut({bool allSessions = false}) async {
    _resendTimer?.cancel();
    _pendingOtpEmail = '';
    _errorMessage = null;
    _statusMessage = null;
    if (_client != null && !_currentUser.isGuest) {
      try {
        await _client!.auth.signOut(
          scope: allSessions ? SignOutScope.global : SignOutScope.local,
        );
      } catch (_) {}
    }
    _currentUser = AppUser.unauthenticated();
    diagnostics.logEvent(
      allSessions ? 'Signed out from all sessions.' : 'Signed out from current device.',
    );
    notifyListeners();
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    _resendCooldownSeconds = seconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldownSeconds > 0) {
        _resendCooldownSeconds -= 1;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }
}
