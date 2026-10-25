import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/services/camera_detection_service.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('camera detector starts idle without fabricated camera results', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final diagnostics = DiagnosticsService();
    final service = CameraDetectionService(diagnostics: diagnostics);

    expect(service.isCameraReady, isFalse);
    expect(service.isLiveStreaming, isFalse);
    expect(service.detections, isEmpty);
    expect(service.engineMode, DetectionEngineMode.mlKitObject);
    expect(service.currentPosture.keypoints, isEmpty);

    service.runYoloBenchmarkSample(userId: 'guest-local-user', isZh: false);
    expect(service.detections, isEmpty);
    expect(service.liveShowcaseFeed, isEmpty);

    service.setEngineMode(
      DetectionEngineMode.yoloV8PosePosture,
      userId: 'guest-local-user',
      isZh: false,
    );
    expect(service.engineMode, DetectionEngineMode.mlKitObject);
    expect(service.errorMessage, contains('YOLO runtime'));

    service.dispose();
    diagnostics.dispose();
  });

  test('Windows camera detector selects the Python YOLO bridge', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final diagnostics = DiagnosticsService();
    final service = CameraDetectionService(diagnostics: diagnostics);

    expect(service.supportsPythonYolo, isTrue);
    expect(service.engineMode, DetectionEngineMode.yoloV8PosePosture);
    expect(service.isCameraReady, isFalse);

    service.dispose();
    diagnostics.dispose();
  });

  test('unavailable pose evaluation contains no generated keypoints', () {
    final posture = PostureEvaluation.unavailable(PostureExerciseTarget.pushUp);

    expect(posture.keypoints, isEmpty);
    expect(posture.formScore, 0);
    expect(posture.headlineEn, 'Pose model unavailable');
  });
}
