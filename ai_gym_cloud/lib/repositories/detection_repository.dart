import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/services/database_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Repository for `public.camera_detections` and optional consent-gated private
/// image storage in the `camera-detections` Supabase Storage bucket.
/// Uses `XFile` instead of `dart:io` so it compiles and runs cleanly on
/// Android, Chrome (Web), Edge (Web), and Windows Desktop.
class DetectionRepository {
  DetectionRepository({
    required this.db,
    required this.prefs,
  });

  final DatabaseService db;
  final PreferenceService prefs;

  Future<List<CameraDetectionRecord>> fetchSavedDetections({
    required String userId,
    required bool isGuest,
  }) async {
    final local = prefs.getLocalDetections();
    if (isGuest || db.client == null) return local;

    try {
      final rows = await db.client!
          .from('camera_detections')
          .select()
          .eq('user_id', userId)
          .order('detected_at', ascending: false)
          .limit(30);
      final parsed = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => CameraDetectionRecord.fromJson({
                ...r,
                'is_saved_to_cloud': true,
              }))
          .toList();
      if (parsed.isNotEmpty) {
        await prefs.saveLocalDetections(parsed);
        return parsed;
      }
      return local;
    } catch (_) {
      return local;
    }
  }

  /// Saves a detection record to `public.camera_detections`.
  /// Original image upload is strictly disabled by default unless
  /// `prefs.cameraSaveConsentEnabled` is true.
  Future<CameraDetectionRecord> saveDetection({
    required CameraDetectionRecord detection,
    required bool isGuest,
    String? localCapturedFilePath,
  }) async {
    String? uploadedPath;

    if (!isGuest && db.client != null) {
      if (prefs.cameraSaveConsentEnabled &&
          localCapturedFilePath != null &&
          localCapturedFilePath.isNotEmpty) {
        try {
          final xfile = XFile(localCapturedFilePath);
          final bytes = await xfile.readAsBytes();
          if (bytes.isNotEmpty) {
            final targetPath = '${detection.userId}/${detection.id}.jpg';
            await db.client!.storage.from('camera-detections').uploadBinary(
                  targetPath,
                  bytes,
                  fileOptions: const FileOptions(
                    upsert: true,
                    contentType: 'image/jpeg',
                  ),
                );
            uploadedPath = targetPath;
          }
        } catch (_) {
          // Safe fallback if local file path is virtual or unavailable on Web
        }
      }

      final recordToSave = detection.copyWith(
        imagePath: uploadedPath,
        isSavedToCloud: true,
      );
      await db.client!
          .from('camera_detections')
          .upsert(recordToSave.toDatabaseRow());

      final existing = prefs.getLocalDetections();
      await prefs.saveLocalDetections([
        recordToSave,
        ...existing.where((d) => d.id != recordToSave.id),
      ]);
      await prefs.setLastSyncState(
        'Camera detection saved ${DateTime.now().toUtc().toIso8601String()}',
      );
      return recordToSave;
    }

    final localSaved = detection.copyWith(isSavedToCloud: false);
    final existing = prefs.getLocalDetections();
    await prefs.saveLocalDetections([
      localSaved,
      ...existing.where((d) => d.id != localSaved.id),
    ]);
    return localSaved;
  }
}
