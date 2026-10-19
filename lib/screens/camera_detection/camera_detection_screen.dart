import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/services/camera_detection_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Android Camera Object Detection screen using `camera` and
/// `google_mlkit_object_detection` (Section 7).
/// IMPORTANT: Never places a BackdropFilter around the animated CameraPreview.
class CameraDetectionScreen extends StatefulWidget {
  const CameraDetectionScreen({
    super.key,
    required this.userId,
    required this.isGuest,
    required this.cameraService,
    required this.prefs,
    required this.savedDetections,
    required this.onSaveDetection,
  });

  final String userId;
  final bool isGuest;
  final CameraDetectionService cameraService;
  final PreferenceService prefs;
  final List<CameraDetectionRecord> savedDetections;
  final Future<void> Function(
    CameraDetectionRecord detection,
    String? localCapturedFilePath,
  ) onSaveDetection;

  @override
  State<CameraDetectionScreen> createState() => _CameraDetectionScreenState();
}

class _CameraDetectionScreenState extends State<CameraDetectionScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.cameraService.stopCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.cameraService.stopCamera();
    }
  }

  Future<void> _handleSaveDetection(
    CameraDetectionRecord det,
    bool isZh,
  ) async {
    try {
      await widget.onSaveDetection(
        det,
        widget.cameraService.lastCapturedFilePath,
      );
      widget.cameraService.markDetectionSaved(det.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isGuest
                ? (isZh ? '已儲存偵測結果至本機（訪客模式）' : 'Saved detection locally (Guest Mode)')
                : (isZh ? '已儲存偵測結果至 Supabase！' : 'Saved detection to Supabase!'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isZh ? '儲存失敗：${e.runtimeType}' : 'Failed to save detection: ${e.runtimeType}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, widget.prefs.languageCode);
    final isZh = strings.isZh;
    final glass = widget.prefs.glassThemeEnabled;

    return ListenableBuilder(
      listenable: widget.cameraService,
      builder: (context, _) {
        final controller = widget.cameraService.cameraController;
        final isReady =
            widget.cameraService.isCameraInitialized && controller != null;
        final detections = widget.cameraService.detections;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            GlassPanel(
              glassEnabled: glass,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: strings.tr('camera_title'),
                    icon: Icons.center_focus_strong,
                  ),
                  Text(
                    strings.tr('camera_privacy_notice'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.privacy_tip_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.prefs.cameraSaveConsentEnabled
                              ? (isZh
                                  ? '原始影像儲存同意：已開啟（將加密存於私人 camera-detections 儲存桶）'
                                  : 'Raw Image Upload Consent: ENABLED (stored in private bucket)')
                              : (isZh
                                  ? '原始影像儲存同意：預設關閉（僅上傳文字標籤與座標）'
                                  : 'Raw Image Upload Consent: DISABLED by default (metadata only)'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.cameraService.errorMessage != null)
              ErrorBannerCard(
                message: widget.cameraService.errorMessage!,
                retryLabel: strings.tr('retry'),
                onRetry: () => widget.cameraService.startCamera(isZh: isZh),
              ),
            // Camera Preview container (No BackdropFilter around live preview!)
            Container(
              height: 320,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isReady)
                    CameraPreview(controller)
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.videocam_off_outlined,
                              color: Colors.white70,
                              size: 48,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isZh
                                  ? '相機尚未啟動。點擊下方「啟動相機」開始預覽與 ML Kit 偵測。'
                                  : 'Camera preview is inactive. Tap "Start Camera" below.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isReady && detections.isNotEmpty)
                    DetectionBoundingBoxOverlay(detections: detections),
                  if (widget.cameraService.isProcessing)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            GlassPanel(
              glassEnabled: glass,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!isReady)
                    FilledButton.icon(
                      onPressed: widget.cameraService.isProcessing
                          ? null
                          : () => widget.cameraService.startCamera(isZh: isZh),
                      icon: const Icon(Icons.videocam_outlined),
                      label: Text(strings.tr('start_camera')),
                    )
                  else ...[
                    FilledButton.icon(
                      onPressed: widget.cameraService.isProcessing
                          ? null
                          : () => widget.cameraService.captureAndDetect(
                                userId: widget.userId,
                                isZh: isZh,
                              ),
                      icon: const Icon(Icons.camera),
                      label: Text(strings.tr('capture_detect')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => widget.cameraService.toggleLiveStream(
                        userId: widget.userId,
                        isZh: isZh,
                      ),
                      icon: Icon(
                        widget.cameraService.isLiveStreaming
                            ? Icons.pause_circle_outline
                            : Icons.stream,
                      ),
                      label: Text(strings.tr('live_stream_toggle')),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.cameraService.stopCamera,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(strings.tr('stop_camera')),
                    ),
                  ],
                  if (detections.isNotEmpty)
                    TextButton.icon(
                      onPressed: widget.cameraService.clearResults,
                      icon: const Icon(Icons.clear_all),
                      label: Text(strings.tr('clear_results')),
                    ),
                ],
              ),
            ),
            GlassPanel(
              glassEnabled: glass,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: isZh
                        ? '目前偵測結果 (${detections.length})'
                        : 'Current Detection Results (${detections.length})',
                    icon: Icons.radar,
                  ),
                  if (detections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        isZh
                            ? '尚無偵測物件。啟動相機後點擊「拍照並執行 ML Kit 偵測」。'
                            : 'No objects detected yet. Start the camera and tap "Capture & Detect".',
                      ),
                    )
                  else
                    ...detections.map(
                      (d) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            '${(d.confidence * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          d.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Box: [${d.boundingBox.left.toStringAsFixed(0)}, '
                          '${d.boundingBox.top.toStringAsFixed(0)}, '
                          '${d.boundingBox.right.toStringAsFixed(0)}, '
                          '${d.boundingBox.bottom.toStringAsFixed(0)}] '
                          '(${d.sourceWidth}×${d.sourceHeight})',
                        ),
                        trailing: d.isSavedToCloud
                            ? const Icon(Icons.cloud_done, color: Colors.green)
                            : FilledButton.tonalIcon(
                                onPressed: () =>
                                    _handleSaveDetection(d, isZh),
                                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                                label: Text(strings.tr('save_detection')),
                              ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.savedDetections.isNotEmpty)
              GlassPanel(
                glassEnabled: glass,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: isZh
                          ? '已儲存之歷史偵測紀錄 (${widget.savedDetections.length})'
                          : 'Saved Cloud/Local Detections (${widget.savedDetections.length})',
                      icon: Icons.history,
                    ),
                    ...widget.savedDetections.take(5).map(
                          (d) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(Icons.check_circle_outline),
                            title: Text(
                              '${d.label} (${(d.confidence * 100).toStringAsFixed(1)}%)',
                            ),
                            subtitle: Text(
                              d.detectedAt.toLocal().toString().substring(0, 19),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
