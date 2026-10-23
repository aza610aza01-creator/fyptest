import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_gym_flutter/models/user_profile.dart';
import 'package:ai_gym_flutter/services/database_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Repository for `public.profiles` with Guest Mode fallback.
class ProfileRepository {
  ProfileRepository({
    required this.db,
    required this.prefs,
  });

  final DatabaseService db;
  final PreferenceService prefs;

  Future<UserProfile> fetchOrCreateProfile({
    required String userId,
    required String defaultDisplayName,
    required bool isGuest,
  }) async {
    if (isGuest || db.client == null) {
      final cached = prefs.getGuestProfile();
      if (cached != null) return cached;
      final initial = UserProfile(
        id: userId,
        displayName: defaultDisplayName.isEmpty ? 'Guest Athlete' : defaultDisplayName,
        language: prefs.languageCode,
        unitSystem: prefs.unitSystem,
        onboardingCompleted: true,
      );
      await prefs.saveGuestProfile(initial);
      return initial;
    }

    try {
      final data = await db.client!
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        final profile = UserProfile.fromJson(data);
        await prefs.setUnitSystem(profile.unitSystem);
        return profile;
      }

      final created = UserProfile(
        id: userId,
        displayName: defaultDisplayName,
        language: prefs.languageCode,
        unitSystem: prefs.unitSystem,
        onboardingCompleted: false,
      );
      await db.client!.from('profiles').upsert(created.toJson());
      return created;
    } on PostgrestException catch (e) {
      db.diagnostics.logEvent('Profile fetch PostgrestException: ${e.code}');
      rethrow;
    }
  }

  Future<UserProfile> upsertProfile({
    required UserProfile profile,
    required bool isGuest,
  }) async {
    final updated = profile.copyWith(onboardingCompleted: true);
    await prefs.setUnitSystem(updated.unitSystem);
    await prefs.setLanguageCode(updated.language);

    if (isGuest || db.client == null) {
      await prefs.saveGuestProfile(updated);
      return updated;
    }

    await db.client!.from('profiles').upsert(updated.toJson());
    await prefs.setLastSyncState(
      'Profile synced ${DateTime.now().toUtc().toIso8601String()}',
    );
    return updated;
  }
}
