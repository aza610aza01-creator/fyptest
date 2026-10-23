import 'package:flutter/foundation.dart';

/// Holds compile-time configuration injected via `--dart-define`.
/// Configured for:
/// - Project: aza610aza01-creator's Project
/// - Organization: aza610aza01-creator's Org | Supabase
/// - Publishable Key: sb_publishable_7psvpRTKPvrcIFZjNcynIQ_KiDD5lgP (overridable via --dart-define)
/// - Guardrail: If a `sb_secret_...` key is passed to `--dart-define`, client browser/mobile
///   sessions automatically use the RLS-safe Publishable Key so Supabase browser checks never fail.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.adminEmail,
    this.supabaseProjectName = defaultSupabaseProjectName,
    this.supabaseOrgName = defaultSupabaseOrgName,
    this.serverSecretKeyConfigured = false,
  });

  static const String defaultSupabaseProjectName =
      "aza610aza01-creator's Project";

  static const String defaultSupabaseOrgName =
      "aza610aza01-creator's Org | Supabase";

  static const String defaultSupabaseUrl =
      'https://eprmvrtcpuydxhtzwfep.supabase.co';

  static const String defaultSupabasePublishableKey =
      'sb_publishable_7psvpRTKPvrcIFZjNcynIQ_KiDD5lgP';

  static const String _envUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: defaultSupabaseUrl,
  );

  static const String _envPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: defaultSupabasePublishableKey,
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

  factory AppConfig.fromEnvironment() {
    final rawPub = _envPublishableKey.trim();
    // Never pass a sb_secret_ key to client-side Supabase.initialize in Chrome/Edge
    final isSecretInPub = rawPub.startsWith('sb_secret_');
    final safePublishableKey = (rawPub.isEmpty || isSecretInPub)
        ? defaultSupabasePublishableKey
        : rawPub;

    return AppConfig(
      supabaseUrl: _envUrl.trim().isEmpty ? defaultSupabaseUrl : _envUrl.trim(),
      supabasePublishableKey: safePublishableKey,
      adminEmail: _envAdminEmail.trim().toLowerCase(),
      serverSecretKeyConfigured:
          isSecretInPub || _envSecretKey.trim().startsWith('sb_secret_'),
    );
  }

  /// Returns true only when both a valid https URL and non-placeholder
  /// Publishable Key are provided.
  bool get isConfigured {
    if (supabaseUrl.isEmpty || !supabaseUrl.startsWith('https://')) {
      return false;
    }
    if (supabasePublishableKey.isEmpty) {
      return false;
    }
    if (supabasePublishableKey == 'YOUR_PUBLISHABLE_KEY' ||
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
