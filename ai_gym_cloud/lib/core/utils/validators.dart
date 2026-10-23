/// Input validation helpers for authentication, profile onboarding, and workouts.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _otpRegex = RegExp(r'^\d{6}$');

  /// Validates an Email address. Returns null when valid, or an error string.
  static String? validateEmail(String? value, {bool isZh = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isZh ? '請輸入 Email 地址' : 'Email address is required.';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return isZh ? '請輸入有效的 Email 格式' : 'Enter a valid Email address.';
    }
    return null;
  }

  /// Validates a password (minimum 8 characters as required by section 3.1).
  static String? validatePassword(String? value, {bool isZh = false}) {
    final pwd = value ?? '';
    if (pwd.isEmpty) {
      return isZh ? '請輸入密碼' : 'Password is required.';
    }
    if (pwd.length < 8) {
      return isZh
          ? '密碼長度必須至少為 8 個字元'
          : 'Password must contain at least 8 characters.';
    }
    return null;
  }

  /// Validates password confirmation match.
  static String? validateConfirmPassword(
    String? password,
    String? confirmPassword, {
    bool isZh = false,
  }) {
    final baseCheck = validatePassword(confirmPassword, isZh: isZh);
    if (baseCheck != null) return baseCheck;
    if (password != confirmPassword) {
      return isZh ? '兩次輸入的密碼不一致' : 'Passwords do not match.';
    }
    return null;
  }

  /// Validates display name.
  static String? validateDisplayName(String? value, {bool isZh = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isZh ? '請輸入顯示名稱' : 'Display name is required.';
    }
    if (trimmed.length < 2) {
      return isZh ? '顯示名稱至少需要 2 個字元' : 'Display name must be at least 2 characters.';
    }
    return null;
  }

  /// Validates a 6-digit Email OTP code.
  static String? validateOtpCode(String? value, {bool isZh = false}) {
    final trimmed = value?.trim() ?? '';
    if (!_otpRegex.hasMatch(trimmed)) {
      return isZh ? '請輸入完整的 6 位數 OTP 驗證碼' : 'Enter a valid 6-digit OTP code.';
    }
    return null;
  }
}
