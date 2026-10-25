import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/services/camera_detection_service.dart';

/// Live Real-Time Camera Detection Showcase widget displayed inside both
/// `CameraDetectionScreen` and `DashboardScreen` so the user can inspect the
/// live YOLOv8n-Pose posture evaluation, joint angles, detected gym equipment,
/// sportswear/cloth items, and real-time frame telemetry feed at any time.
class RealTimeDetectionShowcase extends StatelessWidget {
  const RealTimeDetectionShowcase({
    super.key,
    required this.cameraService,
    required this.userId,
    required this.isZh,
    required this.glassEnabled,
    this.onOpenCameraTab,
    this.showOpenCameraButton = false,
  });

  final CameraDetectionService cameraService;
  final String userId;
  final bool isZh;
  final bool glassEnabled;
  final VoidCallback? onOpenCameraTab;
  final bool showOpenCameraButton;

  Color _postureColor(PostureStatus status) {
    switch (status) {
      case PostureStatus.correct:
        return const Color(0xFF30D158);
      case PostureStatus.needsAdjustment:
        return const Color(0xFFFF9F0A);
      case PostureStatus.incorrect:
        return const Color(0xFFFF453A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cameraService,
      builder: (context, _) {
        final posture = cameraService.currentPosture;
        final hasPoseData = posture.keypoints.isNotEmpty;
        final cameraController = cameraService.cameraController;
        final hasCameraPreview =
            cameraService.isCameraInitialized && cameraController != null;
        final pythonFrame = cameraService.pythonCameraFrame;
        final hasPythonPreview =
            cameraService.isPythonYoloConnected && pythonFrame != null;
        final detections = cameraService.detections
            .where((d) => !d.isPostureCategory)
            .toList();
        final feed = cameraService.liveShowcaseFeed;
        final statusColor = hasPoseData
            ? _postureColor(posture.status)
            : const Color(0xFF64D2FF);
        final stageLabel = cameraService.lifecycleStage.localizedLabel(isZh);
        final hasLatency = cameraService.hasValidLatency;

        return Semantics(
          liveRegion: true,
          label: isZh
              ? '即時相機偵測內容展示：${posture.headlineZh}'
              : 'Real-time camera detection showcase: ${posture.headlineEn}',
          child: GlassPanel(
            glassEnabled: glassEnabled,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header with Live Pulse Badge & Stream Toggle
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: cameraService.isLiveStreaming
                                ? const Color(0xFF30D158)
                                : const Color(0xFFFF9F0A),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (cameraService.isLiveStreaming
                                            ? const Color(0xFF30D158)
                                            : const Color(0xFFFF9F0A))
                                        .withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isZh ? '即時相機偵測內容展示 (Live AI Detection Stream)' : 'Real-Time Camera Detection Showcase (Live Stream)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (cameraService.isVirtualCameraActive)
                          StatusBadge(
                            label: isZh ? '示範模式' : 'DEMO MODE',
                            color: const Color(0xFFFF9F0A),
                            icon: Icons.science_outlined,
                          ),
                        StatusBadge(
                          label: stageLabel,
                          color: statusColor,
                          icon: Icons.sensors,
                        ),
                        if (hasLatency)
                          StatusBadge(
                            label:
                                '${cameraService.lastInferenceMs.toStringAsFixed(1)} ms • ${cameraService.estimatedFps.toStringAsFixed(0)} FPS',
                            color: const Color(0xFF64D2FF),
                            icon: Icons.speed,
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 1B. Live Pushup_Unseen Vector Pose Viewport & Exercise Switcher
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: PostureExerciseTarget.values.map((ex) {
                      final selected = cameraService.targetExercise == ex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 8),
                        child: ChoiceChip(
                          selected: selected,
                          label: Text(
                            isZh ? ex.labelZh : ex.labelEn,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          onSelected: (_) => cameraService.setTargetExercise(
                            ex,
                            userId: userId,
                            isZh: isZh,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Container(
                  height: 190,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      center: Alignment(0.0, -0.2),
                      radius: 1.1,
                      colors: <Color>[Color(0xFF162238), Color(0xFF070B14)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasCameraPreview)
                        Transform.flip(
                          flipX: cameraService.mirrorComputerCamera,
                          child: CameraPreview(cameraController),
                        ),
                      if (hasPythonPreview)
                        Image.memory(
                          pythonFrame,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.low,
                        )
                      else
                        DetectionBoundingBoxOverlay(
                          detections: cameraService.detections,
                          postureEvaluation: posture,
                          flipX:
                              hasCameraPreview &&
                              cameraService.mirrorComputerCamera,
                        ),
                      Positioned(
                        top: 8,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${cameraService.detectionModeDisplayName.split('(').first.trim()} • ${isZh ? posture.exercise.labelZh : posture.exercise.labelEn}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00F5D4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (cameraService.isVirtualCameraActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      isZh
                          ? '示範畫面，不是相機偵測結果。'
                          : 'Demo output; not detections from the camera.',
                      style: const TextStyle(
                        color: Color(0xFFFF9F0A),
                        fontSize: 11,
                      ),
                    ),
                  ),
                if (cameraService.errorMessage != null) ...[
                  Text(
                    cameraService.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // 2. Live Biomechanical Posture & Joint Angle Telemetry Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            posture.isCorrect
                                ? Icons.check_circle_rounded
                                : Icons.warning_amber_rounded,
                            color: statusColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isZh ? posture.headlineZh : posture.headlineEn,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (hasPoseData)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Form ${posture.formScore}%',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isZh ? posture.tipZh : posture.tipEn,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (hasPoseData)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _TelemetryChip(
                              label: posture.primaryJointLabel,
                              value: '${posture.primaryAngleDeg}°',
                              color: statusColor,
                            ),
                            _TelemetryChip(
                              label: posture.secondaryJointLabel,
                              value: '${posture.secondaryAngleDeg}°',
                              color: const Color(0xFF64D2FF),
                            ),
                            _TelemetryChip(
                              label: isZh ? '左右對稱' : 'Symmetry',
                              value: '${posture.symmetryPercent}%',
                              color: const Color(0xFF9ED756),
                            ),
                            _TelemetryChip(
                              label: isZh ? '標準次數' : 'Good Reps',
                              value: '${cameraService.goodRepCount}',
                              color: const Color(0xFF30D158),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Live Detected Objects (Gym Equipment + Sportswear / Gear)
                Text(
                  isZh
                      ? '目前畫面中的物件 (${detections.length})：'
                      : 'Objects detected in frame (${detections.length}):',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                if (detections.isEmpty)
                  Text(
                    isZh ? '啟動相機即時偵測後，偵測結果會顯示於此。' : 'Start live camera detection to show detected objects here.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: detections.take(4).map((det) {
                      final isCloth = det.isClothCategory;
                      final badgeColor = isCloth
                          ? const Color(0xFF64D2FF)
                          : const Color(0xFF9ED756);
                      final box = det.boundingBox;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCloth
                                  ? Icons.checkroom_outlined
                                  : Icons.fitness_center,
                              size: 14,
                              color: badgeColor,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${det.conciseTitle} • ${(det.confidence * 100).round()}% [${box.left.round()},${box.top.round()},${box.width.round()}x${box.height.round()}]',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 10),

                // 4. Live Rolling Frame Log (Real-Time Stream History)
                if (feed.isNotEmpty) ...[
                  Text(
                    isZh
                        ? '即時偵測串流紀錄 (${cameraService.performancePreset.resolutionLabel} • ${cameraService.delegateMode})：'
                        : 'Live Detection Frame Feed (${cameraService.performancePreset.resolutionLabel} • ${cameraService.delegateMode}):',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: feed.take(3).map((frame) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            frame.localizedSummary(isZh),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              color: Color(0xFF64D2FF),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // 5. Interactive Real-Time Stream Controls
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () {
                        if (cameraService.isLiveStreaming) {
                          cameraService.stopLiveStream();
                        } else {
                          cameraService.startRealTimeDetection(
                            userId: userId,
                            isZh: isZh,
                          );
                        }
                      },
                      icon: Icon(
                        cameraService.isLiveStreaming
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        size: 16,
                      ),
                      label: Text(
                        cameraService.isLiveStreaming
                            ? (isZh ? '暫停即時串流' : 'Pause Live Stream')
                            : (isZh ? '啟動即時串流' : 'Start Live Stream'),
                      ),
                    ),
                    if (!cameraService.isCameraInitialized ||
                        cameraService.isVirtualCameraActive)
                      OutlinedButton.icon(
                        onPressed: () => cameraService.cycleVirtualGymScene(
                          userId: userId,
                          isZh: isZh,
                        ),
                        icon: const Icon(Icons.skip_next_outlined, size: 16),
                        label: Text(isZh ? '示範場景' : 'Demo scene'),
                      ),
                    if (showOpenCameraButton && onOpenCameraTab != null)
                      FilledButton.icon(
                        onPressed: onOpenCameraTab,
                        icon: const Icon(Icons.videocam_outlined, size: 16),
                        label: Text(
                          isZh ? '開啟全螢幕 AI 鏡頭' : 'Open Full Camera Coach',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TelemetryChip extends StatelessWidget {
  const _TelemetryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

typedef RealtimeDetectionShowcase = RealTimeDetectionShowcase;
