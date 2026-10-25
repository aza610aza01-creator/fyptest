import 'package:flutter/foundation.dart';

/// Holds compile-time configuration injected via `--dart-define`.
/// Strictly adheres to SEC-1, SEC-2, SEC-3, and HC-1:
/// - No hardcoded Supabase URLs, anon/publishable keys, or server secrets in source.
/// - Reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` (or `SUPABASE_ANON_KEY`)
///   exclusively via `String.fromEnvironment`.
/// - Rejects any `sb_secret_...` or `server-admin` key passed by mistake so the
///   client only ever initializes with an RLS-safe anon/publishable key.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.adminEmail,
    this.supabaseProjectName = defaultSupabaseProjectName,
    this.supabaseOrgName = defaultSupabaseOrgName,
    this.serverSecretKeyConfigured = false,
  });

  static const String defaultSupabaseProjectName = 'AI Gym Cloud Supabase Project';
  static const String defaultSupabaseOrgName = 'AI Gym Cloud Organization';

  static const String defaultSupabaseUrl = '';
  static const String defaultSupabasePublishableKey = '';

  static const String _envUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: defaultSupabaseUrl,
  );

  static const String _envPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: defaultSupabasePublishableKey,
  );

  static const String _envAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String _envSecretKey = String.fromEnvironment(
    'SUPABASE_SECRET_KEY',
    defaultValue: '',
  );

  static const String _envAdminEmail = String.fromEnvironment(
    'ADMIN_EMAIL',
    defaultValue: '',
  );

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String adminEmail;
  final String supabaseProjectName;
  final String supabaseOrgName;
  final bool serverSecretKeyConfigured;

  /// Alias for `supabasePublishableKey` supporting standard `SUPABASE_ANON_KEY` callers.
  String get supabaseAnonKey => supabasePublishableKey;

  factory AppConfig.fromEnvironment() {
    final rawPub = _envPublishableKey.trim().isNotEmpty
        ? _envPublishableKey.trim()
        : _envAnonKey.trim();
    // Never pass a server secret key to client-side Supabase.initialize
    final isSecretInPub = rawPub.startsWith('sb_secret_');
    final safePublishableKey = isSecretInPub ? '' : rawPub;

    return AppConfig(
      supabaseUrl: _envUrl.trim(),
      supabasePublishableKey: safePublishableKey,
      adminEmail: _envAdminEmail.trim().toLowerCase(),
      serverSecretKeyConfigured:
          isSecretInPub || _envSecretKey.trim().startsWith('sb_secret_'),
    );
  }

  /// Returns true only when both a valid https URL and non-placeholder
  /// anon/publishable key are provided via `--dart-define`.
  bool get isConfigured {
    if (supabaseUrl.isEmpty || !supabaseUrl.startsWith('https://')) {
      return false;
    }
    if (supabasePublishableKey.isEmpty) {
      return false;
    }
    if (supabasePublishableKey == 'YOUR_PUBLISHABLE_KEY' ||
        supabasePublishableKey == 'YOUR_SUPABASE_ANON_KEY' ||
        supabasePublishableKey.startsWith('sb_secret_')) {
      return false;
    }
    return true;
  }

  /// Checks whether a verified user email matches the configured ADMIN_EMAIL.
  bool isAdminEmail(
    String? email, {
    required bool isOtpVerified,
    required bool isGuest,
  }) {
    if (isGuest || !isOtpVerified) return false;
    if (adminEmail.isEmpty || email == null || email.trim().isEmpty) {
      return false;
    }
    return email.trim().toLowerCase() == adminEmail;
  }

  /// Masks the Publishable Key so the full key is never displayed in UI or logs.
  String get maskedPublishableKey {
    if (supabasePublishableKey.isEmpty) return 'NOT_SET';
    if (supabasePublishableKey.length <= 10) return '****';
    final prefix = supabasePublishableKey.substring(0, 6);
    final suffix =
        supabasePublishableKey.substring(supabasePublishableKey.length - 4);
    return '$prefix...$suffix';
  }

  /// Masks an email address for safe display in diagnostics.
  static String maskEmail(String? email) {
    if (email == null || email.trim().isEmpty) return 'none';
    final parts = email.trim().split('@');
    if (parts.length != 2) return '***';
    final name = parts[0];
    final domain = parts[1];
    final visible =
        name.length <= 2 ? name.substring(0, 1) : name.substring(0, 2);
    return '$visible***@$domain';
  }

  /// Masks a UUID or user identifier for safe display in diagnostics.
  static String maskUserId(String? userId) {
    if (userId == null || userId.trim().isEmpty) return 'none';
    final clean = userId.trim();
    if (clean.length <= 8) return '****';
    return '${clean.substring(0, 4)}...${clean.substring(clean.length - 4)}';
  }

  /// Returns current Flutter build mode name.
  static String get buildModeName {
    if (kReleaseMode) return 'Release';
    if (kProfileMode) return 'Profile';
    return 'Debug';
  }
}
