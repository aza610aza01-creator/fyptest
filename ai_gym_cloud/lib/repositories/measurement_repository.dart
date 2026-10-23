import 'package:ai_gym_flutter/models/body_measurement.dart';
import 'package:ai_gym_flutter/models/health_and_coaching_models.dart';
import 'package:ai_gym_flutter/services/database_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Repository for `public.body_measurements` and `public.health_logs`.
class MeasurementRepository {
  MeasurementRepository({
    required this.db,
    required this.prefs,
  });

  final DatabaseService db;
  final PreferenceService prefs;

  Future<List<BodyMeasurement>> fetchMeasurements({
    required String userId,
    required bool isGuest,
  }) async {
    final local = prefs.getLocalMeasurements();
    if (isGuest || db.client == null) return local;
    try {
      final rows = await db.client!
          .from('body_measurements')
          .select()
          .eq('user_id', userId)
          .order('recorded_at', ascending: false)
          .limit(30);
      final parsed = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(BodyMeasurement.fromJson)
          .toList();
      if (parsed.isNotEmpty) {
        await prefs.saveLocalMeasurements(parsed);
        return parsed;
      }
      return local;
    } catch (_) {
      return local;
    }
  }

  Future<void> saveMeasurement({
    required BodyMeasurement measurement,
    required bool isGuest,
  }) async {
    final local = prefs.getLocalMeasurements();
    final updated = [
      measurement,
      ...local.where((m) => m.id != measurement.id),
    ];
    await prefs.saveLocalMeasurements(updated);

    if (isGuest || db.client == null) return;
    try {
      await db.client!.from('body_measurements').upsert(measurement.toJson());
      await prefs.setLastSyncState(
        'Measurement synced ${DateTime.now().toUtc().toIso8601String()}',
      );
    } catch (e) {
      db.diagnostics.logEvent('Measurement cached locally (${e.runtimeType})');
    }
  }

  Future<List<HealthLogRecord>> fetchHealthLogs({
    required String userId,
    required bool isGuest,
  }) async {
    final local = prefs.getLocalHealthLogs();
    if (isGuest || db.client == null) return local;
    try {
      final rows = await db.client!
          .from('health_logs')
          .select()
          .eq('user_id', userId)
          .order('recorded_date', ascending: false)
          .limit(30);
      final parsed = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(HealthLogRecord.fromJson)
          .toList();
      if (parsed.isNotEmpty) {
        await prefs.saveLocalHealthLogs(parsed);
        return parsed;
      }
      return local;
    } catch (_) {
      return local;
    }
  }

  Future<void> saveHealthLog({
    required HealthLogRecord log,
    required bool isGuest,
  }) async {
    final local = prefs.getLocalHealthLogs();
    final updated = [
      log,
      ...local.where((h) => h.recordedDate != log.recordedDate),
    ];
    await prefs.saveLocalHealthLogs(updated);

    if (isGuest || db.client == null) return;
    try {
      await db.client!.from('health_logs').upsert(log.toJson());
    } catch (e) {
      db.diagnostics.logEvent('Health log cached locally (${e.runtimeType})');
    }
  }
}
