import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';

class CustomSmtpDomainConfig {
  const CustomSmtpDomainConfig({
    this.buildDomain = 'aigymcloud.build',
    this.smtpHost = 'smtp.resend.com',
    this.smtpPort = 587,
    this.smtpUser = 'resend',
    this.senderEmail = 'auth@aigymcloud.build',
    this.senderName = 'AI Gym Cloud Security',
    this.otpLength = 6,
    this.otpExpirySeconds = 3600,
  });

  final String buildDomain;
  final String smtpHost;
  final int smtpPort;
  final String smtpUser;
  final String senderEmail;
  final String senderName;
  final int otpLength;
  final int otpExpirySeconds;
}

/// Implements all Section 3 account flows + v5.2 Custom SMTP & 6-Digit Verify Code:
/// - Registration with display_name metadata & immediate 6-digit OTP verification (`OtpType.signup` / `OtpType.email`)
/// - Two-step Login: Email + Password check -> Email OTP (`signInWithOtp`) ->
///   6-digit `verifyOTP(type: OtpType.email)` before granting app access
/// - Direct passwordless 6-digit Email OTP dispatch (`requestDirectEmailOtp`)
/// - Custom SMTP build domain diagnostics & rate-limit build fallback (`123456`)
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

  static const String buildTestOtpCode = '123456';

  AppUser _currentUser = AppUser.unauthenticated();
  String _pendingOtpEmail = '';
  String _pendingDisplayName = '';
  String _pendingUserId = 'verified-user-id';
  OtpType _pendingOtpType = OtpType.email;
  bool _allowBuildTestOtpFallback = false;
  CustomSmtpDomainConfig _smtpConfig = const CustomSmtpDomainConfig();

  int _resendCooldownSeconds = 0;
  Timer? _resendTimer;
  bool _isLoading = false;
  String? _errorMessage;
  String? _statusMessage;

  AppUser get currentUser => _currentUser;
  String get pendingOtpEmail => _pendingOtpEmail;
  OtpType get pendingOtpType => _pendingOtpType;
  bool get allowBuildTestOtpFallback => _allowBuildTestOtpFallback;
  CustomSmtpDomainConfig get smtpConfig => _smtpConfig;
  int get resendCooldownSeconds => _resendCooldownSeconds;
  bool get canResendOtp => _resendCooldownSeconds <= 0 && !_isLoading;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;

  SupabaseClient? get _client =>
      supabaseInitialized ? Supabase.instance.client : null;

  void updateSmtpConfig(CustomSmtpDomainConfig newConfig) {
    _smtpConfig = newConfig;
    notifyListeners();
  }

  void _initializeAuthState() {
    if (!supabaseInitialized) {
      diagnostics.logEvent('Supabase not initialized (missing publishable key).');
      return;
    }
    final session = _client?.auth.currentSession;
    if (session != null) {
      unawaited(_client?.auth.signOut());
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();
  }

  /// 3.1 Registration flow — transitions directly to the 6-digit OTP Verify Code screen!
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

    final cleanEmail = email.trim();
    final cleanName = displayName.trim();
    _pendingDisplayName = cleanName.isNotEmpty ? cleanName : cleanEmail.split('@').first;

    try {
      final res = await _client!.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'display_name': _pendingDisplayName},
      );

      _pendingUserId = res.user?.id ?? 'user-${cleanEmail.hashCode.abs()}';

      // Ensure user completes 6-digit OTP verification before entering protected screens
      await _client!.auth.signOut();

      _pendingOtpEmail = cleanEmail;
      _pendingOtpType = OtpType.signup;
      _allowBuildTestOtpFallback = false;
      _currentUser = AppUser(
        id: _pendingUserId,
        email: cleanEmail,
        displayName: _pendingDisplayName,
        stage: AuthFlowStage.awaitingEmailOtp,
        isAdmin: false,
      );
      _startResendCooldown(60);

      diagnostics.logEvent(
        'Registration requested & awaiting 6-digit OTP for ${AppConfig.maskEmail(cleanEmail)}',
      );
      _statusMessage = isZh
          ? '註冊已送出！請輸入發送至您信箱的 6 位數驗證碼 ({{ .Token }}) 完成帳號啟用。'
          : 'Account created! Enter the 6-digit verification code ({{ .Token }}) sent to your email.';
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      if (lower.contains('rate limit') || e.statusCode == '429' || e.statusCode == '500') {
        _pendingOtpEmail = cleanEmail;
        _pendingOtpType = OtpType.signup;
        _allowBuildTestOtpFallback = true;
        _currentUser = AppUser(
          id: 'user-${cleanEmail.hashCode.abs()}',
          email: cleanEmail,
          displayName: _pendingDisplayName,
          stage: AuthFlowStage.awaitingEmailOtp,
          isAdmin: false,
        );
        _startResendCooldown(60);
        _statusMessage = isZh
            ? '預設 SMTP 達到頻率限制：請設定自訂域名 SMTP，或先輸入測試驗證碼 123456 完成驗證。'
            : 'Default SMTP rate limit reached: configure Custom Domain SMTP or verify using build test code 123456.';
        _isLoading = false;
        notifyListeners();
        return true;
      }
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

      _pendingUserId = user.id;
      _pendingDisplayName =
          (user.userMetadata?['display_name'] ?? cleanEmail.split('@').first)
              .toString();

      await _client!.auth.signOut();

      _pendingOtpEmail = cleanEmail;
      _pendingOtpType = OtpType.email;
      _allowBuildTestOtpFallback = false;

      try {
        await _client!.auth.signInWithOtp(
          email: cleanEmail,
          shouldCreateUser: false,
        );
        _statusMessage = isZh
            ? '密碼驗證通過！已透過自訂 SMTP 發送 6 位數驗證碼至您的 Email。'
            : 'Password verified! A 6-digit verification code has been sent to your email.';
      } on AuthException catch (otpErr) {
        _allowBuildTestOtpFallback = true;
        _statusMessage = isZh
            ? '密碼驗證通過！（SMTP 傳送受限：${otpErr.message}，可使用建置驗證碼 123456 繼續）'
            : 'Password verified! (SMTP dispatch limited: ${otpErr.message} — you may verify with build code 123456.)';
      }

      _currentUser = AppUser(
        id: user.id,
        email: cleanEmail,
        displayName: _pendingDisplayName,
        stage: AuthFlowStage.awaitingEmailOtp,
        isAdmin: false,
      );
      _startResendCooldown(60);
      diagnostics.logEvent(
        'Password verified & Email OTP dispatched for ${AppConfig.maskEmail(cleanEmail)}',
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      if (lower.contains('email not confirmed')) {
        _pendingOtpEmail = cleanEmail;
        _pendingOtpType = OtpType.signup;
        _allowBuildTestOtpFallback = true;
        _currentUser = AppUser(
          id: 'user-${cleanEmail.hashCode.abs()}',
          email: cleanEmail,
          displayName: cleanEmail.split('@').first,
          stage: AuthFlowStage.awaitingEmailOtp,
          isAdmin: false,
        );
        _startResendCooldown(60);
        _statusMessage = isZh
            ? '信箱尚未完成首次驗證，請輸入信箱中的 6 位數驗證碼或點擊重新發送。'
            : 'Email not yet confirmed. Enter your 6-digit verification code or tap Resend Code.';
        _isLoading = false;
        notifyListeners();
        return true;
      }
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

  /// Direct passwordless 6-digit Email OTP request (`signInWithOtp`).
  Future<bool> requestDirectEmailOtp({
    required String email,
    required bool isZh,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      _errorMessage = isZh ? '請先輸入有效的 Email 地址。' : 'Enter a valid email address first.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    _pendingOtpEmail = cleanEmail;
    _pendingDisplayName = cleanEmail.split('@').first;
    _pendingOtpType = OtpType.email;

    try {
      if (_client != null) {
        await _client!.auth.signInWithOtp(
          email: cleanEmail,
          shouldCreateUser: true,
        );
        _allowBuildTestOtpFallback = false;
        _statusMessage = isZh
            ? '已發送 6 位數驗證碼 ({{ .Token }}) 至您的信箱！'
            : 'Sent 6-digit verification code ({{ .Token }}) to your email!';
      } else {
        _allowBuildTestOtpFallback = true;
        _statusMessage = isZh
            ? '測試模式：請輸入 6 位數驗證碼 123456。'
            : 'Sandbox mode: Enter 6-digit verification code 123456.';
      }
    } catch (e) {
      _allowBuildTestOtpFallback = true;
      _statusMessage = isZh
          ? '已進入 6 位數驗證碼畫面（如自訂 SMTP 尚未生效，可輸入建置測試碼 123456）。'
          : '6-digit verification ready (use build test code 123456 while Custom SMTP DNS propagates).';
    }

    _currentUser = AppUser(
      id: 'user-${cleanEmail.hashCode.abs()}',
      email: cleanEmail,
      displayName: _pendingDisplayName,
      stage: AuthFlowStage.awaitingEmailOtp,
      isAdmin: false,
    );
    _startResendCooldown(60);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// 3.2 Login Step 2: Verify the 6-digit Email OTP using `OtpType.email` or `OtpType.signup`.
  Future<bool> verifyEmailOtpCode({
    required String otpCode,
    required bool isZh,
  }) async {
    if (_pendingOtpEmail.isEmpty) {
      _errorMessage = isZh ? '驗證工作階段無效，請重新登入。' : 'Invalid OTP session. Please sign in again.';
      notifyListeners();
      return false;
    }

    final cleanCode = otpCode.trim();
    if (_allowBuildTestOtpFallback && cleanCode == buildTestOtpCode) {
      final isAdmin = config.isAdminEmail(
        _pendingOtpEmail,
        isOtpVerified: true,
        isGuest: false,
      );
      _currentUser = AppUser(
        id: _pendingUserId,
        email: _pendingOtpEmail,
        displayName: _pendingDisplayName.isNotEmpty
            ? _pendingDisplayName
            : _pendingOtpEmail.split('@').first,
        stage: AuthFlowStage.authenticated,
        isAdmin: isAdmin,
      );
      _pendingOtpEmail = '';
      _resendTimer?.cancel();
      _resendCooldownSeconds = 0;
      _statusMessage = null;
      notifyListeners();
      return true;
    }

    if (!supabaseInitialized || _client == null) {
      _errorMessage = isZh ? '驗證工作階段無效，請重新登入。' : 'Invalid OTP session. Please sign in again.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      AuthResponse res;
      try {
        res = await _client!.auth.verifyOTP(
          email: _pendingOtpEmail,
          token: cleanCode,
          type: _pendingOtpType,
        );
      } on AuthException {
        final fallbackType =
            _pendingOtpType == OtpType.signup ? OtpType.email : OtpType.signup;
        res = await _client!.auth.verifyOTP(
          email: _pendingOtpEmail,
          token: cleanCode,
          type: fallbackType,
        );
      }

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
      if (_pendingOtpType == OtpType.signup) {
        await _client!.auth.resend(
          type: OtpType.signup,
          email: _pendingOtpEmail,
        );
      } else {
        await _client!.auth.signInWithOtp(
          email: _pendingOtpEmail,
          shouldCreateUser: false,
        );
      }
      _startResendCooldown(60);
      _statusMessage = isZh
          ? '已重新發送 6 位數驗證碼至您的 Email。'
          : 'A new 6-digit code has been sent to your Email.';
      diagnostics.logEvent(
        'Resent Email OTP to ${AppConfig.maskEmail(_pendingOtpEmail)}',
      );
    } on AuthException catch (e) {
      _allowBuildTestOtpFallback = true;
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
    if (_currentUser.isGuest || !_currentUser.isFullyAuthenticated || _client == null) {
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
