import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/services/camera_detection_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';
import 'package:ai_gym_flutter/widgets/realtime_detection_showcase.dart';

/// Modern, humanized, and concise AI Posture & Vision Coaching Screen:
/// - Streams live from the computer webcam or phone camera with a 17-keypoint YOLOv8n-Pose skeleton overlay
/// - Evaluates real-time gym posture correctness (Squat, Bicep Curl, Shoulder Press, Deadlift)
/// - Keeps advanced trained YOLO model & lens settings tucked in a clean collapsible drawer.
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
  )
  onSaveDetection;

  @override
  State<CameraDetectionScreen> createState() => _CameraDetectionScreenState();
}

class _CameraDetectionScreenState extends State<CameraDetectionScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isZh = widget.prefs.languageCode.toLowerCase().startsWith('zh');
      if (!widget.cameraService.isCameraReady &&
          !widget.cameraService.isWebTarget &&
          !widget.cameraService.isMacOSTarget) {
        widget.cameraService.openComputerCamera(
          isZh: isZh,
          userId: widget.userId,
        );
      }
    });
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
    } else if (state == AppLifecycleState.resumed &&
        !widget.cameraService.isCameraReady &&
        !widget.cameraService.isWebTarget) {
      widget.cameraService.openComputerCamera(
        isZh: widget.prefs.languageCode.toLowerCase().startsWith('zh'),
        userId: widget.userId,
      );
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
                ? (isZh ? '已儲存姿勢分析紀錄（訪客模式）' : 'Saved posture snapshot locally')
                : (isZh
                      ? '已同步姿勢分析紀錄至雲端！'
                      : 'Synced posture snapshot to Supabase!'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isZh ? '儲存失敗：${e.runtimeType}' : 'Save failed: ${e.runtimeType}',
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
        final svc = widget.cameraService;
        final controller = svc.cameraController;
        final hasHardwarePreview =
            svc.isCameraInitialized && controller != null;
        final pythonFrame = svc.pythonCameraFrame;
        final hasPythonPreview =
            svc.isPythonYoloConnected && pythonFrame != null;
        final hasMacOSPreview = svc.isMacOSTarget && svc.isMacOSCameraRequested;
        final posture = svc.currentPosture;
        final hasPoseData = posture.keypoints.isNotEmpty;
        final detections = svc.detections;
        final lenses = svc.availableLenses;

        final statusColor = hasPoseData
            ? switch (posture.status) {
                PostureStatus.correct => const Color(0xFF30D158),
                PostureStatus.needsAdjustment => const Color(0xFFFF9F0A),
                PostureStatus.incorrect => const Color(0xFFFF453A),
              }
            : const Color(0xFF64D2FF);

        final statusBadgeText = hasPoseData
            ? switch (posture.status) {
                PostureStatus.correct => isZh ? '✓ 姿勢標準' : '✓ Correct Form',
                PostureStatus.needsAdjustment =>
                  isZh ? '⚠ 建議微調' : '⚠ Adjust Form',
                PostureStatus.incorrect => isZh ? '✕ 姿勢警示' : '✕ Form Alert',
              }
            : (isZh ? '尚無姿勢模型' : 'Pose model unavailable');
        final activeStatusBadgeText = hasPythonPreview
            ? (svc.isLiveStreaming ? 'Python YOLO Live' : 'Python YOLO Paused')
            : statusBadgeText;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
          children: [
            // 1. Concise Exercise Target Selector Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: PostureExerciseTarget.values.map((ex) {
                  final active = svc.targetExercise == ex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: active,
                      label: Text(
                        isZh ? ex.labelZh : ex.labelEn,
                        style: TextStyle(
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      onSelected: (_) => svc.setTargetExercise(
                        ex,
                        userId: widget.userId,
                        isZh: isZh,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Live camera viewfinder with detections from the active detector.
            Container(
              height: 350,
              decoration: BoxDecoration(
                color: const Color(0xFF070B10),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.55),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasHardwarePreview)
                    Transform.flip(
                      flipX: svc.mirrorComputerCamera,
                      child: CameraPreview(controller),
                    )
                  else if (hasPythonPreview)
                    Image.memory(
                      pythonFrame,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                    )
                  else if (hasMacOSPreview)
                    CameraMacOSView(
                      key: const ValueKey<String>('macos-camera-preview'),
                      cameraMode: CameraMacOSMode.photo,
                      enableAudio: false,
                      fit: BoxFit.cover,
                      onCameraInizialized: svc.markMacOSCameraInitialized,
                      onCameraLoading: (error) {
                        if (error != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              svc.markMacOSCameraError(error, isZh: isZh);
                            }
                          });
                        }
                        return Center(
                          child: error == null
                              ? const CircularProgressIndicator()
                              : Text(
                                  error.toString(),
                                  style: const TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                        );
                      },
                    )
                  else if (svc.isVirtualCameraActive)
                    _VirtualGymCameraCanvas(
                      sceneIndex: svc.virtualSceneIndex,
                      isStreaming: svc.isLiveStreaming,
                      isZh: isZh,
                    )
                  else
                    _CameraUnavailableCanvas(
                      isZh: isZh,
                      message: svc.errorMessage,
                    ),

                  // 17-Keypoint Skeleton + Equipment Overlay
                  if (!hasPythonPreview && !hasMacOSPreview)
                    DetectionBoundingBoxOverlay(
                      detections: detections,
                      postureEvaluation: posture,
                      flipX: hasHardwarePreview && svc.mirrorComputerCamera,
                    ),

                  if (svc.errorMessage != null)
                    Positioned(
                      top: 54,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          svc.errorMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  // Top Floating HUD Bar
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${svc.detectionModeDisplayName.split('(').first.trim()} • ${svc.hasValidLatency ? "${svc.lastInferenceMs.toStringAsFixed(1)} ms" : (isZh ? "待機" : "idle")}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.75),
                            ),
                          ),
                          child: Text(
                            hasPoseData
                                ? '$activeStatusBadgeText • ${posture.formScore}%'
                                : activeStatusBadgeText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Floating Quick Camera Action Bar
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.75,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: svc.isProcessing
                              ? null
                              : () => svc.openComputerCamera(
                                  userId: widget.userId,
                                  isZh: isZh,
                                ),
                          icon: Icon(
                            hasHardwarePreview ||
                                    hasPythonPreview ||
                                    hasMacOSPreview
                                ? Icons.videocam
                                : Icons.laptop_chromebook,
                            size: 16,
                            color: const Color(0xFF64D2FF),
                          ),
                          label: Text(
                            hasPythonPreview
                                ? (svc.isLiveStreaming
                                      ? 'Python YOLO Live'
                                      : 'Python YOLO Paused')
                                : (hasMacOSPreview
                                      ? (svc.isCameraReady
                                            ? 'Mac Camera Live'
                                            : (isZh
                                                  ? '正在啟動相機...'
                                                  : 'Starting Camera...'))
                                      : (hasHardwarePreview
                                            ? (isZh
                                                  ? '鏡頭連線中'
                                                  : 'Webcam Live')
                                            : (isZh
                                                  ? '啟用相機'
                                                  : 'Use Camera'))),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          tooltip: isZh ? '水平鏡像翻轉' : 'Mirror Camera',
                          onPressed: svc.toggleMirrorComputerCamera,
                          icon: const Icon(Icons.flip, size: 17),
                        ),
                        const SizedBox(width: 6),
                        if (svc.supportsLiveInference)
                          IconButton.filledTonal(
                            tooltip: svc.isLiveStreaming
                                ? (isZh ? '暫停即時偵測' : 'Pause Live Coach')
                                : (isZh ? '繼續即時偵測' : 'Resume Live Coach'),
                            onPressed: () => svc.toggleLiveStream(
                              userId: widget.userId,
                              isZh: isZh,
                            ),
                            icon: Icon(
                              svc.isLiveStreaming
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 18,
                            ),
                          ),
                        if (!svc.supportsLiveInference)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              isZh ? '僅相機預覽' : 'Preview only',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (hasPoseData)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isZh
                                  ? '標準次數 ${posture.goodReps}'
                                  : '${posture.goodReps} Good Reps',
                              style: const TextStyle(
                                color: Color(0xFF30D158),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (svc.isProcessing)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3. Humanized Real-Time Coaching Feedback Card
            GlassPanel(
              glassEnabled: glass,
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasPoseData)
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            posture.isCorrect
                                ? Icons.check_circle_rounded
                                : (posture.status ==
                                          PostureStatus.needsAdjustment
                                      ? Icons.tune_rounded
                                      : Icons.warning_amber_rounded),
                            color: statusColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isZh ? posture.headlineZh : posture.headlineEn,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isZh ? posture.tipZh : posture.tipEn,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      isZh ? '物件方框來自相機畫面；姿勢指導需要另外載入姿勢模型。' : 'Object boxes come from the camera feed. Form coaching requires a separate pose model.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  // Concise 3-Metric Biomechanical Strip
                  if (hasPoseData)
                    Row(
                      children: [
                        _MetricPill(
                          label: posture.primaryJointLabel,
                          value: '${posture.primaryAngleDeg}°',
                          accent: statusColor,
                        ),
                        const SizedBox(width: 8),
                        _MetricPill(
                          label: posture.secondaryJointLabel,
                          value: '${posture.secondaryAngleDeg}°',
                          accent: const Color(0xFF64D2FF),
                        ),
                        const SizedBox(width: 8),
                        _MetricPill(
                          label: isZh ? '左右對稱' : 'Symmetry',
                          value: '${posture.symmetryPercent}%',
                          accent: const Color(0xFF9ED756),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  // Quick Posture State Tester + Cloud Save Row
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (svc.isVirtualCameraActive) ...[
                        _PosturePresetChip(
                          label: isZh ? '自動即時' : 'Auto Live',
                          selected: svc.postureSimulationPreset == 0,
                          onTap: () => svc.setPostureSimulationPreset(
                            0,
                            userId: widget.userId,
                            isZh: isZh,
                          ),
                        ),
                        _PosturePresetChip(
                          label: isZh ? '✓ 標準姿勢' : '✓ Correct',
                          selected: svc.postureSimulationPreset == 1,
                          onTap: () => svc.setPostureSimulationPreset(
                            1,
                            userId: widget.userId,
                            isZh: isZh,
                          ),
                        ),
                        _PosturePresetChip(
                          label: isZh ? '⚠ 深度微調' : '⚠ Shallow',
                          selected: svc.postureSimulationPreset == 2,
                          onTap: () => svc.setPostureSimulationPreset(
                            2,
                            userId: widget.userId,
                            isZh: isZh,
                          ),
                        ),
                        _PosturePresetChip(
                          label: isZh ? '✕ 圓背警示' : '✕ Form Alert',
                          selected: svc.postureSimulationPreset == 3,
                          onTap: () => svc.setPostureSimulationPreset(
                            3,
                            userId: widget.userId,
                            isZh: isZh,
                          ),
                        ),
                      ],
                      if (detections.isNotEmpty)
                        ActionChip(
                          avatar: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 15,
                          ),
                          label: Text(
                            isZh ? '儲存姿勢快照' : 'Save Snapshot',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () =>
                              _handleSaveDetection(detections.first, isZh),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // 3.5 Real-Time Camera Detection Content Showcase (Live Stream of Posture, Joint Angles & Objects)
            RealTimeDetectionShowcase(
              cameraService: svc,
              userId: widget.userId,
              isZh: isZh,
              glassEnabled: glass,
              showOpenCameraButton: false,
            ),

            // 3.6 Explicit Camera Permission / Model State & Captured Image Privacy Controls
            GlassPanel(
              glassEnabled: glass,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${isZh ? "鏡頭與模型狀態" : "Camera & Model Status"}: ${svc.lifecycleStage.localizedLabel(isZh)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (svc.lifecycleStage ==
                          CameraLifecycleStage.permissionPermanentlyDenied)
                        TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isZh ? '請於系統設定 > 權限中開啟相機存取權，然後點擊重試。' : 'Open System Settings > Permissions to allow Camera access, then tap Retry.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.settings_outlined, size: 15),
                          label: Text(strings.tr('open_settings_permission')),
                        ),
                      TextButton.icon(
                        onPressed: () => svc.openComputerCamera(
                          userId: widget.userId,
                          isZh: isZh,
                        ),
                        icon: const Icon(Icons.refresh, size: 15),
                        label: Text(strings.tr('retry')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: CameraPerformancePreset.values.map((preset) {
                      final selected = svc.performancePreset == preset;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(
                          preset.localizedLabel(isZh),
                          style: const TextStyle(fontSize: 11),
                        ),
                        onSelected: (_) => svc.setPerformancePreset(
                          preset,
                          userId: widget.userId,
                          isZh: isZh,
                        ),
                      );
                    }).toList(),
                  ),
                  if (svc.lastCapturedFilePath != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isZh ? '已拍攝快取影像：僅在開啟私隱同意時上傳' : 'Captured image cached locally (uploaded only with consent)',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              svc.deleteLastCapturedImage(isZh: isZh),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: Text(
                            isZh ? '刪除快取影像' : 'Delete Captured Image',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    strings.tr('medical_disclaimer'),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),

            // 3.7 Developer Mode Camera Diagnostics (Visible only when Developer Mode is enabled)
            if (widget.prefs.developerModeEnabled)
              GlassPanel(
                glassEnabled: glass,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.developer_board,
                          size: 18,
                          color: Color(0xFF64D2FF),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isZh
                              ? '開發者相機與模型即時診斷 (Developer Diagnostics)'
                              : 'Developer Camera & AI Diagnostics',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'FPS: ${svc.estimatedFps.toStringAsFixed(1)} • '
                      'Latency: ${svc.hasValidLatency ? "${svc.lastInferenceMs.toStringAsFixed(1)} ms" : "N/A"} • '
                      'Resolution: ${svc.performancePreset.resolutionLabel} • '
                      'Conf: ${(svc.yoloConfidenceThreshold * 100).round()}% • '
                      'Delegate: ${svc.delegateMode} • '
                      'Last Detection: ${svc.lastDetectionTimestampUtc?.toIso8601String().substring(11, 19) ?? "None"}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

            // Detector and camera configuration.
            GlassPanel(
              glassEnabled: glass,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.memory, size: 20),
                title: Text(
                  isZh ? '相機偵測設定' : 'Camera Detection Settings',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  svc.activeTrainedModel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                children: [
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue:
                        svc.availableTrainedYoloModels.contains(
                          svc.activeTrainedModel,
                        )
                        ? svc.activeTrainedModel
                        : svc.availableTrainedYoloModels.first,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isZh ? '目前偵測模型' : 'Active object detector',
                    ),
                    items: svc.availableTrainedYoloModels
                        .map(
                          (m) => DropdownMenuItem<String>(
                            value: m,
                            child: Text(
                              m,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        svc.selectTrainedYoloModel(
                          val,
                          userId: widget.userId,
                          isZh: isZh,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    svc.supportsPythonYolo
                        ? (isZh
                              ? 'Windows 使用 python_gym_pose 的 YOLO + MediaPipe。執行 RUN_FLUTTER.bat 後即可連線。'
                              : 'Windows uses YOLO + MediaPipe from python_gym_pose. Run RUN_FLUTTER.bat to connect.')
                        : (svc.isWebTarget
                              ? (isZh
                                    ? 'Chrome/Edge 網頁版僅支援相機預覽。要使用 YOLO，請改用 Windows 桌面版，並先執行 python_gym_pose\\RUN_FLUTTER.bat。'
                                    : 'Chrome/Edge web builds provide camera preview only. For YOLO, use the Windows desktop app and first run python_gym_pose\\RUN_FLUTTER.bat.')
                              : (isZh
                                    ? 'Android/iOS 使用內建物件偵測；此版本未附加其他 YOLO 權重。'
                                    : 'Android/iOS use on-device object detection; no additional YOLO weights are bundled.')),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  if (svc.availableEngineModes.isNotEmpty)
                    DropdownButtonFormField<DetectionEngineMode>(
                      initialValue: svc.engineMode,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: isZh ? '推論模式' : 'Inference Head Mode',
                      ),
                      items: svc.availableEngineModes
                          .map(
                            (mode) => DropdownMenuItem<DetectionEngineMode>(
                              value: mode,
                              child: Text(mode.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          svc.setEngineMode(
                            val,
                            userId: widget.userId,
                            isZh: isZh,
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 10),
                  if (lenses.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List<Widget>.generate(lenses.length, (idx) {
                        final selected =
                            hasHardwarePreview &&
                            svc.selectedCameraIndex == idx;
                        return ChoiceChip(
                          selected: selected,
                          label: Text(
                            svc.formatLensLabel(idx, isZh: isZh),
                            style: const TextStyle(fontSize: 11),
                          ),
                          onSelected: (_) => svc.callPhysicalLensIndex(
                            idx,
                            userId: widget.userId,
                            isZh: isZh,
                          ),
                        );
                      }),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      isZh ? '標籤信心門檻' : 'Label confidence threshold',
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Slider(
                      value: svc.yoloConfidenceThreshold,
                      min: 0.25,
                      max: 0.90,
                      divisions: 13,
                      label: '${(svc.yoloConfidenceThreshold * 100).round()}%',
                      onChanged: svc.setYoloConfidenceThreshold,
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

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosturePresetChip extends StatelessWidget {
  const _PosturePresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _VirtualGymCameraCanvas extends StatelessWidget {
  const _VirtualGymCameraCanvas({
    required this.sceneIndex,
    required this.isStreaming,
    required this.isZh,
  });

  final int sceneIndex;
  final bool isStreaming;
  final bool isZh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.15),
          radius: 1.05,
          colors: <Color>[Color(0xFF162434), Color(0xFF070B10)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _GymGridPainter()),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFFF9F0A)),
              ),
              child: Text(
                isZh ? '示範模式 • 非相機影像' : 'DEMO MODE • NOT CAMERA VIDEO',
                style: const TextStyle(
                  color: Color(0xFFFF9F0A),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraUnavailableCanvas extends StatelessWidget {
  const _CameraUnavailableCanvas({required this.isZh, this.message});

  final bool isZh;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF070B10),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                size: 42,
                color: Color(0xFF64D2FF),
              ),
              const SizedBox(height: 12),
              Text(
                message ??
                    (isZh
                        ? '啟用相機以開始偵測'
                        : 'Enable the camera to start detection'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GymGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
