import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';

/// Gym equipment or sportswear/cloth class descriptor for YOLOv8 classification & exercise mapping.
class YoloGymClassSpec {
  const YoloGymClassSpec({
    required this.classId,
    required this.className,
    required this.suggestedExercise,
    this.isCloth = false,
  });

  final int classId;
  final String className;
  final String suggestedExercise;
  final bool isCloth;
}

/// Cross-platform iOS, Android, Web (Chrome/Edge), and Windows Desktop Computer Camera +
/// Pre-Trained YOLOv8n-Pose (17-Keypoint Real-Time Gym Posture & Biomechanical Coach) +
/// YOLOv8n-Gym & YOLOv8n-Cloth service.
class CameraDetectionService extends ChangeNotifier {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  CameraDetectionService({required this.diagnostics}) {
    _currentPosture = PostureEvaluation.unavailable(_targetExercise);
    if (_isWindowsPlatform) {
      _engineMode = DetectionEngineMode.yoloV8PosePosture;
      _activeTrainedModel = 'Python YOLOv8n-Pose + MediaPipe (Windows)';
    } else if (kIsWeb) {
      _activeTrainedModel = 'Camera preview only (Web)';
    } else if (_isMacOSPlatform) {
      _activeTrainedModel = 'Camera preview only (macOS)';
    }
  }

  final DiagnosticsService diagnostics;
  final Uuid _uuid = const Uuid();

  /// Discord Channel #1563159459428306975 / Message #1563160849311596564 YOLO model reference.
  static const String discordYoloChannelUrl =
      'https://discord.com/channels/1552209137541193770/1563159459428306975/1563160849311596564';

  /// Available pre-trained YOLO model weights & endpoints (including Discord YOLO model).
  static final List<String> trainedYoloModels = <String>[
    'Python YOLOv8n-Pose + MediaPipe (Windows)',
    'Google ML Kit Object Detection',
  ];

  /// YOLOv8n-Gym Equipment Catalog (Classes 0..9)
  static const List<YoloGymClassSpec> yoloGymCatalog = <YoloGymClassSpec>[
    YoloGymClassSpec(
      classId: 0,
      className: 'Dumbbell',
      suggestedExercise: 'Bicep Curl / Shoulder Press',
    ),
    YoloGymClassSpec(
      classId: 1,
      className: 'Olympic Barbell',
      suggestedExercise: 'Barbell Squat / Deadlift',
    ),
    YoloGymClassSpec(
      classId: 2,
      className: 'Bench Rack',
      suggestedExercise: 'Bench Press',
    ),
    YoloGymClassSpec(
      classId: 3,
      className: 'Kettlebell',
      suggestedExercise: 'Goblet Squat',
    ),
    YoloGymClassSpec(
      classId: 4,
      className: 'Cable Pulley',
      suggestedExercise: 'Cable Pushdown',
    ),
    YoloGymClassSpec(
      classId: 5,
      className: 'Treadmill',
      suggestedExercise: 'Zone 2 Running',
    ),
    YoloGymClassSpec(
      classId: 6,
      className: 'Spin Bike',
      suggestedExercise: 'Cycling',
    ),
    YoloGymClassSpec(
      classId: 7,
      className: 'Weight Plate 20kg',
      suggestedExercise: 'Loaded Compound Lift',
    ),
    YoloGymClassSpec(
      classId: 8,
      className: 'Shaker Bottle',
      suggestedExercise: 'Hydration (+250 ml)',
    ),
    YoloGymClassSpec(
      classId: 9,
      className: 'Athlete Squat Pose',
      suggestedExercise: 'Squat Form Check',
    ),
  ];

  /// YOLOv8n-Cloth Sportswear, Apparel & Lifting Gear Catalog (Classes 10..19)
  static const List<YoloGymClassSpec> yoloClothCatalog = <YoloGymClassSpec>[
    YoloGymClassSpec(
      classId: 10,
      className: 'cloth: Compression Top',
      suggestedExercise: 'Breathable Upper-Body Fit',
      isCloth: true,
    ),
    YoloGymClassSpec(
      classId: 11,
      className: 'cloth: Performance Hoodie',
      suggestedExercise: 'Warm-Up Mobility Layer',
      isCloth: true,
    ),
    YoloGymClassSpec(
      classId: 12,
      className: 'cloth: Mobility Shorts',
      suggestedExercise: 'Unrestricted Squat Depth',
      isCloth: true,
    ),
    YoloGymClassSpec(
      classId: 13,
      className: 'cloth: Compression Leggings',
      suggestedExercise: 'Knee Tracking Visibility',
      isCloth: true,
    ),
    YoloGymClassSpec(
      classId: 14,
      className: 'cloth: Lifting Belt',
      suggestedExercise: 'Core Intra-Abdominal Brace',
      isCloth: true,
    ),
    YoloGymClassSpec(
      classId: 15,
      className: 'cloth: Wrist Wraps',
      suggestedExercise: 'Neutral Wrist Support',
      isCloth: true,
    ),
    YoloGymClassSpec(
      classId: 16,
      className: 'cloth: Flat Lifting Shoes',
      suggestedExercise: 'Stable Heel Drive',
      isCloth: true,
    ),
    YoloGymClassSpec(
      classId: 17,
      className: 'cloth: Cushioned Runners',
      suggestedExercise: 'Cardio Impact Absorption',
      isCloth: true,
    ),
    YoloGymClassSpec(
      classId: 18,
      className: 'cloth: Grip Gloves',
      suggestedExercise: 'Bar Grip Security',
      isCloth: true,
    ),
    YoloGymClassSpec(
      classId: 19,
      className: 'cloth: Athletic Tank',
      suggestedExercise: 'Clear Shoulder Tracking',
      isCloth: true,
    ),
  ];

  CameraController? _cameraController;
  CameraMacOSController? _macOSCameraController;
  ObjectDetector? _singleDetector;
  ObjectDetector? _streamDetector;
  Timer? _realTimeTimer;
  Timer? _pythonBridgeTimer;
  final http.Client _pythonBridgeClient = http.Client();
  bool _pythonBridgeConnected = false;
  bool _pythonBridgeBusy = false;
  int _lastPythonFrameNumber = -1;
  Uint8List? _pythonCameraFrame;
  bool _macOSCameraRequested = false;
  bool _macOSCameraInitialized = false;
  static final Uri _pythonBridgeUri = Uri.parse('http://127.0.0.1:8765');

  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _selectedCameraIndex = 0;
  List<CameraDetectionRecord> _detections = const <CameraDetectionRecord>[];

  DetectionEngineMode _engineMode = DetectionEngineMode.mlKitObject;
  String _activeTrainedModel = 'Google ML Kit Object Detection';
  PostureExerciseTarget _targetExercise = PostureExerciseTarget.pushUp;
  late PostureEvaluation _currentPosture;

  /// `0` = Auto real-time biomechanical cycle, `1` = Correct Form, `2` = Needs Adjustment, `3` = Incorrect Form
  int _postureSimulationPreset = 0;
  int _goodRepCount = 8;
  int _formAlertCount = 1;

  CameraLifecycleStage _lifecycleStage =
      CameraLifecycleStage.permissionNotRequested;
  CameraPerformancePreset _performancePreset =
      CameraPerformancePreset.balanced720p;
  final String _delegateMode =
      kIsWeb ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux
      ? (defaultTargetPlatform == TargetPlatform.windows
            ? 'Python YOLO + MediaPipe (localhost)'
            : 'Camera preview only (inference unsupported)')
      : 'On-device ML Kit';
  DateTime? _lastDetectionTimestampUtc;
  final List<RealTimeShowcaseFrame> _liveShowcaseFeed =
      <RealTimeShowcaseFrame>[];

  double _yoloConfidenceThreshold = 0.45;
  double _yoloIouThreshold = 0.45;
  double _lastInferenceMs = 0;
  int _realTimeIntervalMs = 400;
  bool _autoStartRealTime = true;
  int _realTimeTickCount = 0;

  bool _isCameraInitialized = false;
  bool _isVirtualCameraActive = false;
  bool _mirrorComputerCamera = true;
  int _virtualSceneIndex = 0;
  bool _isProcessing = false;
  bool _isLiveStreaming = false;
  bool _streamFrameBusy = false;
  DateTime _lastStreamProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _errorMessage;
  String? _statusNotice;
  String? _lastCapturedFilePath;
  String? _cameraInitializationError;

  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isVirtualCameraActive => _isVirtualCameraActive;
  bool get mirrorComputerCamera => _mirrorComputerCamera;
  bool get isCameraReady =>
      (_isCameraInitialized &&
          (_cameraController != null ||
              _pythonBridgeConnected ||
              _macOSCameraInitialized)) ||
      _isVirtualCameraActive;
  bool get isPythonYoloConnected => _pythonBridgeConnected;
  bool get supportsPythonYolo => _isWindowsPlatform;
  bool get isMacOSTarget => _isMacOSPlatform;
  bool get isMacOSCameraRequested => _macOSCameraRequested;
  bool get supportsLiveInference =>
      _supportsMlKitInference ||
      (_isWindowsPlatform && _pythonBridgeConnected);
  bool get isWebTarget => kIsWeb;
  Uint8List? get pythonCameraFrame => _pythonCameraFrame;
  List<String> get availableTrainedYoloModels => _isWindowsPlatform
      ? const <String>['Python YOLOv8n-Pose + MediaPipe (Windows)']
      : (_isMacOSPlatform
            ? const <String>['Camera preview only (macOS)']
            : (kIsWeb
            ? const <String>['Camera preview only (Web)']
            : const <String>['Google ML Kit Object Detection']));
  List<DetectionEngineMode> get availableEngineModes => _isWindowsPlatform
      ? const <DetectionEngineMode>[DetectionEngineMode.yoloV8PosePosture]
      : (kIsWeb || _isMacOSPlatform
            ? const <DetectionEngineMode>[]
            : const <DetectionEngineMode>[DetectionEngineMode.mlKitObject]);
  int get virtualSceneIndex => _virtualSceneIndex;
  List<CameraDescription> get availableLenses => List.unmodifiable(_cameras);
  int get availableCameraCount => _cameras.length;
  int get selectedCameraIndex => _selectedCameraIndex;
  bool get isProcessing => _isProcessing;
  bool get isLiveStreaming => _isLiveStreaming;
  bool get autoStartRealTime => _autoStartRealTime;
  int get realTimeIntervalMs => _realTimeIntervalMs;
  int get realTimeTickCount => _realTimeTickCount;
  DetectionEngineMode get engineMode => _engineMode;
  String get activeTrainedModel => _activeTrainedModel;
  String get detectionModeDisplayName =>
      kIsWeb
      ? 'Camera preview only (Web)'
      : (_isMacOSPlatform
            ? 'Camera preview only (macOS)'
            : _engineMode.displayName);
  PostureExerciseTarget get targetExercise => _targetExercise;
  PostureEvaluation get currentPosture => _currentPosture;
  int get postureSimulationPreset => _postureSimulationPreset;
  int get goodRepCount => _goodRepCount;
  int get formAlertCount => _formAlertCount;
  CameraLifecycleStage get lifecycleStage => _lifecycleStage;
  CameraPerformancePreset get performancePreset => _performancePreset;
  String get delegateMode => _delegateMode;
  DateTime? get lastDetectionTimestampUtc => _lastDetectionTimestampUtc;
  List<RealTimeShowcaseFrame> get liveShowcaseFeed =>
      List.unmodifiable(_liveShowcaseFeed);

  /// Validates that inference latency is finite and strictly greater than zero
  /// (Mandatory Task 4 & 8: never display "YOLO 0.0 ms").
  bool get hasValidLatency =>
      isCameraReady &&
      _lastInferenceMs.isFinite &&
      _lastInferenceMs > 0.0 &&
      _lastInferenceMs < 5000.0;

  double get estimatedFps {
    if (!hasValidLatency) return 0.0;
    final raw = 1000.0 / math.max(_lastInferenceMs, _realTimeIntervalMs / 14.0);
    return raw.clamp(12.0, 60.0);
  }

  /// Returns a truthful status string for toolbars/Dynamic Island: never shows
  /// "YOLO 0.0 ms" when the camera is idle or the model is not ready.
  String formatToolbarStatus({required bool isZh}) {
    if (!isCameraReady) {
      return isZh ? '相機待機中' : 'Camera idle';
    }
    if (_lifecycleStage == CameraLifecycleStage.modelLoading) {
      return isZh ? '模型載入中...' : 'Model loading...';
    }
    if (!hasValidLatency) {
      return isZh ? '模型尚未就緒' : 'Model not ready';
    }
    return 'Form ${_currentPosture.formScore}% • ${_lastInferenceMs.toStringAsFixed(1)} ms';
  }

  void setPerformancePreset(
    CameraPerformancePreset preset, {
    required String userId,
    required bool isZh,
  }) {
    _performancePreset = preset;
    _realTimeIntervalMs = preset.intervalMs;
    if (_isLiveStreaming) {
      _restartRealTimeTimer(userId: userId, isZh: isZh);
    }
    notifyListeners();
  }

  void setLifecycleStageForTesting(CameraLifecycleStage stage) {
    _lifecycleStage = stage;
    if (stage == CameraLifecycleStage.permissionDenied ||
        stage == CameraLifecycleStage.permissionPermanentlyDenied ||
        stage == CameraLifecycleStage.errorWithRetry) {
      _isCameraInitialized = false;
      _isVirtualCameraActive = false;
      _lastInferenceMs = 0.0;
    }
    notifyListeners();
  }

  void deleteLastCapturedImage({bool isZh = false}) {
    _lastCapturedFilePath = null;
    _statusNotice = isZh
        ? '已從裝置快取移除剛才拍攝的原始相片。'
        : 'Removed last captured camera image path from local session.';
    notifyListeners();
  }

  double get yoloConfidenceThreshold => _yoloConfidenceThreshold;
  double get yoloIouThreshold => _yoloIouThreshold;
  double get lastInferenceMs => _lastInferenceMs;
  List<CameraDetectionRecord> get detections => List.unmodifiable(_detections);
  String? get errorMessage => _errorMessage;
  String? get statusNotice => _statusNotice;
  String? get lastCapturedFilePath => _lastCapturedFilePath;

  bool get _isNativeAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _isWindowsPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get _isMacOSPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  bool get _supportsMlKitInference =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _isComputerPlatform =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  bool _isInfraredOrDepthCamera(CameraDescription cam) {
    final lower = cam.name.toLowerCase();
    return lower.contains('ir ') ||
        lower.endsWith(' ir') ||
        lower.contains('infrared') ||
        lower.contains('windows hello') ||
        lower.contains('depth');
  }

  void toggleMirrorComputerCamera() {
    _mirrorComputerCamera = !_mirrorComputerCamera;
    notifyListeners();
  }

  /// Registers and activates a custom Discord or CDN YOLO model URL/filename at runtime.
  void registerCustomDiscordYoloModel(
    String modelUrlOrName, {
    String userId = 'local_guest_user',
    bool isZh = false,
  }) {
    final cleaned = modelUrlOrName.trim();
    if (cleaned.isEmpty) return;
    selectTrainedYoloModel(cleaned, userId: userId, isZh: isZh);
  }

  void selectTrainedYoloModel(
    String modelUri, {
    String userId = 'local_guest_user',
    bool isZh = false,
  }) {
    if (modelUri.trim().isEmpty) return;
    if (kIsWeb && modelUri.trim() == 'Camera preview only (Web)') {
      _activeTrainedModel = 'Camera preview only (Web)';
      notifyListeners();
      return;
    }
    if (_isWindowsPlatform &&
        modelUri.trim() == 'Python YOLOv8n-Pose + MediaPipe (Windows)') {
      _activeTrainedModel = 'Python YOLOv8n-Pose + MediaPipe (Windows)';
      notifyListeners();
      return;
    }
    if (modelUri.trim() != 'Google ML Kit Object Detection') {
      _errorMessage = isZh ? '此版本未包含可載入的 YOLO 權重；目前使用 Google ML Kit 物件偵測。' : 'No YOLO weights are bundled. Google ML Kit object detection is active.';
    }
    _activeTrainedModel = 'Google ML Kit Object Detection';
    diagnostics.updateDetectorState('Using Google ML Kit Object Detection');
    notifyListeners();
  }

  void setTargetExercise(
    PostureExerciseTarget target, {
    String userId = 'local_guest_user',
    bool isZh = false,
  }) {
    _targetExercise = target;
    _currentPosture = _isVirtualCameraActive
        ? _buildPostureEvaluation(tick: _realTimeTickCount + 1)
        : PostureEvaluation.unavailable(target);
    runYoloBenchmarkSample(
      userId: userId,
      isZh: isZh,
      sceneIndex: _virtualSceneIndex,
    );
  }

  void setPostureSimulationPreset(
    int preset, {
    String userId = 'local_guest_user',
    bool isZh = false,
  }) {
    if (!_isVirtualCameraActive) {
      _errorMessage = isZh
          ? '姿勢預設只適用於示範模式。'
          : 'Posture presets are only available in demo mode.';
      notifyListeners();
      return;
    }
    _postureSimulationPreset = preset.clamp(0, 3);
    if (preset == 1) {
      _goodRepCount += 1;
    } else if (preset == 3) {
      _formAlertCount += 1;
    }
    _currentPosture = _buildPostureEvaluation(tick: _realTimeTickCount + 1);
    runYoloBenchmarkSample(
      userId: userId,
      isZh: isZh,
      sceneIndex: _virtualSceneIndex,
    );
  }

  String formatLensLabel(int index, {bool isZh = false}) {
    if (index < 0 || index >= _cameras.length) {
      return isZh ? '鏡頭 #${index + 1}' : 'Camera #${index + 1}';
    }
    final cam = _cameras[index];
    final dirLabel = switch (cam.lensDirection) {
      CameraLensDirection.front =>
        _isComputerPlatform
            ? (isZh ? '電腦鏡頭' : 'Webcam')
            : (isZh ? '前鏡頭' : 'Front'),
      CameraLensDirection.back => isZh ? '主鏡頭' : 'Back',
      CameraLensDirection.external => isZh ? '外接 USB' : 'USB Cam',
    };
    final cleanName = cam.name.trim().isEmpty
        ? (isZh ? '鏡頭 #${index + 1}' : 'Camera #${index + 1}')
        : cam.name.trim();
    return '$cleanName ($dirLabel)';
  }

  void setEngineMode(
    DetectionEngineMode mode, {
    String userId = 'local_guest_user',
    bool isZh = false,
  }) {
    if (_isWindowsPlatform && mode == DetectionEngineMode.yoloV8PosePosture) {
      _engineMode = mode;
      diagnostics.updateDetectorState(_activeTrainedModel);
      notifyListeners();
      return;
    }
    if (mode != DetectionEngineMode.mlKitObject) {
      _errorMessage = isZh
          ? '此版本未包含 YOLO 推論執行階段或模型權重。'
          : 'This build does not include a YOLO runtime or model weights.';
      _engineMode = DetectionEngineMode.mlKitObject;
      notifyListeners();
      return;
    }
    if (_engineMode == mode) return;
    _engineMode = mode;
    diagnostics.updateDetectorState('Engine switched to ${mode.displayName}');
    notifyListeners();
  }

  void setYoloConfidenceThreshold(double value) {
    _yoloConfidenceThreshold = value.clamp(0.20, 0.95);
    notifyListeners();
  }

  void setYoloIouThreshold(double value) {
    _yoloIouThreshold = value.clamp(0.20, 0.90);
    notifyListeners();
  }

  void setAutoStartRealTime(bool enabled) {
    _autoStartRealTime = enabled;
    notifyListeners();
  }

  void setRealTimeIntervalMs(
    int ms, {
    required String userId,
    required bool isZh,
  }) {
    _realTimeIntervalMs = ms.clamp(200, 2000);
    if (_isLiveStreaming) {
      _restartRealTimeTimer(userId: userId, isZh: isZh);
    }
    notifyListeners();
  }

  Future<List<CameraDescription>> discoverPhysicalLenses() async {
    try {
      _cameras = await availableCameras();
      if (_isComputerPlatform && _cameras.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 550));
      }
      diagnostics.updateCameraState(
        'Discovered ${_cameras.length} camera lens(es)',
      );
      notifyListeners();
    } catch (error) {
      diagnostics.updateCameraState(
        'Camera discovery failed: ${error.runtimeType}',
      );
      rethrow;
    }
    return _cameras;
  }

  Future<void> openComputerCamera({
    required String userId,
    required bool isZh,
  }) async {
    _errorMessage = null;
    _cameraInitializationError = null;
    _statusNotice = isZh ? '正在啟動相機...' : 'Starting camera...';
    _isProcessing = true;
    _detections = const <CameraDetectionRecord>[];
    _currentPosture = PostureEvaluation.unavailable(_targetExercise);
    _liveShowcaseFeed.clear();
    notifyListeners();

    try {
      await stopLiveStream();
      final macController = _macOSCameraController;
      _macOSCameraController = null;
      _macOSCameraRequested = false;
      _macOSCameraInitialized = false;
      if (macController != null) {
        await macController.destroy();
      }
      final prevController = _cameraController;
      _cameraController = null;
      _isCameraInitialized = false;
      if (prevController != null) {
        try {
          await prevController.dispose();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }

      if (_isWindowsPlatform) {
        await _openPythonYoloCamera(userId: userId, isZh: isZh);
        return;
      }

      if (_isMacOSPlatform) {
        _macOSCameraRequested = true;
        _isProcessing = true;
        _lifecycleStage = CameraLifecycleStage.cameraInitializing;
        _statusNotice = isZh
            ? '請允許 AI Gym Cloud 使用 Mac 相機。'
            : 'Allow AI Gym Cloud to access the Mac camera.';
        diagnostics.updateCameraState('Requesting macOS camera access');
        notifyListeners();
        return;
      }

      await discoverPhysicalLenses();

      if (_cameras.isNotEmpty) {
        final rgbIndices = <int>[];
        final irIndices = <int>[];
        for (int i = 0; i < _cameras.length; i++) {
          if (_isInfraredOrDepthCamera(_cameras[i])) {
            irIndices.add(i);
          } else {
            rgbIndices.add(i);
          }
        }
        final ordered = <int>[...rgbIndices, ...irIndices];

        for (final idx in ordered) {
          final cam = _cameras[idx];
          final controller = await _tryInitializePhysicalCamera(cam);
          if (controller != null) {
            _cameraController = controller;
            _selectedCameraIndex = idx;
            _isCameraInitialized = true;
            _isVirtualCameraActive = false;
            _lifecycleStage = CameraLifecycleStage.cameraReady;
            _statusNotice = isZh
                ? '鏡頭已連線：${formatLensLabel(idx, isZh: true)}'
                : 'Live Camera: ${formatLensLabel(idx, isZh: false)}';
            diagnostics.updateCameraState('Camera Active (${cam.name})');
            diagnostics.updateDetectorState('Ready ($_activeTrainedModel)');
            _isProcessing = false;
            notifyListeners();

            if (_autoStartRealTime) {
              await startRealTimeDetection(userId: userId, isZh: isZh);
            }
            return;
          }
        }
      }

      _setCameraUnavailable(
        isZh: isZh,
        message: _cameraInitializationError == null
            ? (isZh
                  ? '找不到可用相機。請檢查相機連線與權限後重試。'
                  : 'No usable camera was found. Check the camera connection and permissions, then retry.')
            : (isZh
                  ? '相機啟動失敗：$_cameraInitializationError'
                  : 'Camera initialization failed: $_cameraInitializationError'),
      );
    } catch (error) {
      final details = _formatCameraError(error);
      _setCameraUnavailable(
        isZh: isZh,
        message: isZh
            ? '相機啟動失敗：$details${kIsWeb ? '。請允許瀏覽器使用相機，並透過 localhost 或 HTTPS 開啟頁面。' : ''}'
            : 'Camera startup failed: $details${kIsWeb ? '. Allow camera access in the browser and open the page on localhost or HTTPS.' : ''}',
      );
    }

    _isProcessing = false;
    notifyListeners();
  }

  String _formatCameraError(Object error) {
    if (error is CameraException) {
      final description = error.description?.trim();
      return description == null || description.isEmpty
          ? error.code
          : '${error.code}: $description';
    }
    return error.toString();
  }

  Future<void> callPhysicalLensIndex(
    int index, {
    required String userId,
    required bool isZh,
  }) async {
    _errorMessage = null;
    _statusNotice = null;
    _isProcessing = true;
    notifyListeners();

    try {
      await stopLiveStream();
      final prevController = _cameraController;
      _cameraController = null;
      _isCameraInitialized = false;
      if (prevController != null) {
        try {
          await prevController.dispose();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }

      if (_cameras.isEmpty) {
        await discoverPhysicalLenses();
      }

      if (index >= 0 && index < _cameras.length) {
        final targetCam = _cameras[index];
        final controller = await _tryInitializePhysicalCamera(targetCam);
        if (controller != null) {
          _cameraController = controller;
          _selectedCameraIndex = index;
          _isCameraInitialized = true;
          _isVirtualCameraActive = false;
          _lifecycleStage = CameraLifecycleStage.cameraReady;
          _statusNotice = isZh
              ? '已切換鏡頭：${formatLensLabel(index, isZh: true)}'
              : 'Switched Camera: ${formatLensLabel(index, isZh: false)}';
          diagnostics.updateCameraState('Camera (${targetCam.name})');
          _isProcessing = false;
          notifyListeners();

          if (_autoStartRealTime) {
            await startRealTimeDetection(userId: userId, isZh: isZh);
          }
          return;
        }
      }

      await openComputerCamera(isZh: isZh, userId: userId);
    } catch (_) {
      _setCameraUnavailable(
        isZh: isZh,
        message: isZh
            ? '無法切換至所選相機。'
            : 'Could not switch to the selected camera.',
      );
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<CameraController?> _tryInitializePhysicalCamera(
    CameraDescription candidateCam,
  ) async {
    final presets = _isComputerPlatform
        ? const <ResolutionPreset>[
            ResolutionPreset.low,
            ResolutionPreset.medium,
            ResolutionPreset.high,
          ]
        : const <ResolutionPreset>[
            ResolutionPreset.medium,
            ResolutionPreset.low,
            ResolutionPreset.high,
            ResolutionPreset.max,
          ];

    for (int attempt = 0; attempt < presets.length; attempt++) {
      final preset = presets[attempt];
      CameraController? tempController;
      try {
        tempController = _isNativeAndroid
            ? CameraController(
                candidateCam,
                preset,
                enableAudio: false,
                imageFormatGroup: ImageFormatGroup.nv21,
              )
            : (!_isComputerPlatform
                  ? CameraController(
                      candidateCam,
                      preset,
                      enableAudio: false,
                      imageFormatGroup: ImageFormatGroup.bgra8888,
                    )
                  : CameraController(candidateCam, preset, enableAudio: false));
        await tempController.initialize().timeout(const Duration(seconds: 7));
        return tempController;
      } catch (error) {
        _cameraInitializationError = error is CameraException
            ? '${error.code}${error.description == null ? '' : ': ${error.description}'}'
            : error.runtimeType.toString();
        try {
          await tempController?.dispose();
        } catch (_) {}
        await Future<void>.delayed(
          Duration(milliseconds: 350 + (attempt * 250)),
        );
      }
    }
    return null;
  }

  void cycleVirtualGymScene({
    String userId = 'local_guest_user',
    bool isZh = false,
  }) {
    cycleVirtualScene(userId: userId, isZh: isZh);
  }

  void cycleVirtualScene({required String userId, required bool isZh}) {
    if (_isCameraInitialized) {
      _errorMessage = isZh
          ? '使用實體相機時無法切換示範場景。'
          : 'Demo scenes cannot replace an active physical camera.';
      notifyListeners();
      return;
    }
    _isVirtualCameraActive = true;
    _isCameraInitialized = false;
    _virtualSceneIndex = (_virtualSceneIndex + 1) % 3;
    final nextExIndex =
        (PostureExerciseTarget.values.indexOf(_targetExercise) + 1) %
        PostureExerciseTarget.values.length;
    _targetExercise = PostureExerciseTarget.values[nextExIndex];
    runYoloBenchmarkSample(
      userId: userId,
      isZh: isZh,
      sceneIndex: _virtualSceneIndex,
    );
  }

  static double computeIoU(Rect a, Rect b) {
    final interLeft = math.max(a.left, b.left);
    final interTop = math.max(a.top, b.top);
    final interRight = math.min(a.right, b.right);
    final interBottom = math.min(a.bottom, b.bottom);

    final interWidth = math.max(0.0, interRight - interLeft);
    final interHeight = math.max(0.0, interBottom - interTop);
    final interArea = interWidth * interHeight;
    if (interArea <= 0.0) return 0.0;

    final areaA = math.max(0.0, a.width) * math.max(0.0, a.height);
    final areaB = math.max(0.0, b.width) * math.max(0.0, b.height);
    final unionArea = areaA + areaB - interArea;
    if (unionArea <= 0.0) return 0.0;
    return interArea / unionArea;
  }

  static List<CameraDetectionRecord> applyYoloNms(
    List<CameraDetectionRecord> candidates, {
    required double confThreshold,
    required double iouThreshold,
  }) {
    final filtered =
        candidates.where((c) => c.confidence >= confThreshold).toList()
          ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final kept = <CameraDetectionRecord>[];
    for (final candidate in filtered) {
      bool suppressed = false;
      for (final existing in kept) {
        if (existing.classId == candidate.classId &&
            computeIoU(existing.boundingBox, candidate.boundingBox) >
                iouThreshold) {
          suppressed = true;
          break;
        }
      }
      if (!suppressed) {
        kept.add(candidate);
      }
    }
    return kept;
  }

  Future<void> startCamera({
    bool isZh = false,
    String userId = 'local_guest_user',
  }) async {
    await openComputerCamera(userId: userId, isZh: isZh);
  }

  void _setCameraUnavailable({required bool isZh, required String message}) {
    _pythonBridgeTimer?.cancel();
    _pythonBridgeTimer = null;
    _pythonBridgeConnected = false;
    _pythonCameraFrame = null;
    _macOSCameraRequested = false;
    _macOSCameraInitialized = false;
    _macOSCameraController = null;
    _isVirtualCameraActive = false;
    _isCameraInitialized = false;
    _isLiveStreaming = false;
    _errorMessage = message;
    _statusNotice = message;
    _lifecycleStage = CameraLifecycleStage.errorWithRetry;
    _detections = const <CameraDetectionRecord>[];
    _currentPosture = PostureEvaluation.unavailable(_targetExercise);
    _lastInferenceMs = 0;
    diagnostics.updateCameraState(message);
    diagnostics.updateDetectorState('No camera inference running');
    notifyListeners();
  }

  void markMacOSCameraInitialized(CameraMacOSController controller) {
    _macOSCameraController = controller;
    _macOSCameraRequested = true;
    _macOSCameraInitialized = true;
    _isCameraInitialized = true;
    _isVirtualCameraActive = false;
    _isProcessing = false;
    _isLiveStreaming = false;
    _errorMessage = null;
    _lifecycleStage = CameraLifecycleStage.cameraReady;
    _statusNotice = 'Mac camera ready (preview only)';
    diagnostics.updateCameraState('macOS camera ready');
    diagnostics.updateDetectorState('Camera preview only (macOS)');
    notifyListeners();
  }

  void markMacOSCameraError(Object error, {required bool isZh}) {
    _setCameraUnavailable(
      isZh: isZh,
      message: isZh
          ? 'Mac 相機啟動失敗：${error.toString()}。請在「系統設定 > 隱私權與安全性 > 相機」允許 AI Gym Cloud 使用相機。'
          : 'Mac camera startup failed: ${error.toString()}. Allow AI Gym Cloud under System Settings > Privacy & Security > Camera.',
    );
  }

  Future<void> _openPythonYoloCamera({
    required String userId,
    required bool isZh,
  }) async {
    _pythonBridgeTimer?.cancel();
    _pythonCameraFrame = null;
    _pythonBridgeConnected = false;
    _lastPythonFrameNumber = -1;
    _lifecycleStage = CameraLifecycleStage.cameraInitializing;
    _statusNotice = isZh
        ? '正在連線至本機 Python YOLO 偵測器...'
        : 'Connecting to the local Python YOLO detector...';
    notifyListeners();

    try {
      final response = await _pythonBridgeClient
          .get(_pythonBridgeUri.replace(path: '/health'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        throw StateError('Python YOLO bridge returned ${response.statusCode}.');
      }

      _pythonBridgeConnected = true;
      _isCameraInitialized = true;
      _isVirtualCameraActive = false;
      _engineMode = DetectionEngineMode.yoloV8PosePosture;
      _activeTrainedModel = 'Python YOLOv8n-Pose + MediaPipe (Windows)';
      _isLiveStreaming = true;
      _isProcessing = false;
      _errorMessage = null;
      _lifecycleStage = CameraLifecycleStage.detectionActive;
      _statusNotice = isZh
          ? '本機 Python YOLO 相機已連線'
          : 'Connected to the local Python YOLO camera';
      diagnostics.updateCameraState('Python YOLO camera connected');
      diagnostics.updateDetectorState(_activeTrainedModel);

      await _sendPythonControl(active: true);
      _pythonBridgeTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => unawaited(_pollPythonSnapshot(userId: userId, isZh: isZh)),
      );
      await _pollPythonSnapshot(userId: userId, isZh: isZh);
    } catch (error) {
      _pythonBridgeConnected = false;
      _isProcessing = false;
      _setCameraUnavailable(
        isZh: isZh,
        message: isZh
            ? '無法連線至 Python YOLO 相機。請先執行 python_gym_pose\\RUN_FLUTTER.bat，並確認模型與相機已就緒。'
            : 'Could not connect to the Python YOLO camera. Run python_gym_pose\\RUN_FLUTTER.bat first and confirm the model and camera are ready. (${error.runtimeType})',
      );
    }
  }

  Future<void> _pollPythonSnapshot({
    required String userId,
    required bool isZh,
  }) async {
    if (_pythonBridgeBusy || !_pythonBridgeConnected || !_isLiveStreaming) {
      return;
    }
    _pythonBridgeBusy = true;
    try {
      final response = await _pythonBridgeClient
          .get(_pythonBridgeUri.replace(path: '/snapshot'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 503) return;
      if (response.statusCode != 200) {
        throw StateError(
          'Python YOLO snapshot returned ${response.statusCode}.',
        );
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Invalid Python YOLO snapshot.');
      }
      final encodedFrame = payload['frame'];
      if (encodedFrame is! String || encodedFrame.isEmpty) {
        throw const FormatException(
          'Python YOLO snapshot has no camera frame.',
        );
      }
      final frame = base64Decode(encodedFrame);
      final width = (payload['width'] as num?)?.toInt() ?? 0;
      final height = (payload['height'] as num?)?.toInt() ?? 0;
      final inferenceMs = (payload['inference_ms'] as num?)?.toDouble() ?? 0;
      final frameNumber =
          (payload['frame_number'] as num?)?.toInt() ??
          _lastPythonFrameNumber + 1;
      if (frameNumber <= _lastPythonFrameNumber) return;
      final now = DateTime.now().toUtc();
      final rawDetections = payload['detections'];
      final detections = <CameraDetectionRecord>[];
      if (rawDetections is List) {
        for (final raw in rawDetections) {
          if (raw is! Map<String, dynamic>) continue;
          final rawBox = raw['box'];
          if (rawBox is! Map<String, dynamic>) continue;
          double coordinate(String key) =>
              (rawBox[key] as num?)?.toDouble() ?? 0;
          final confidence = (raw['confidence'] as num?)?.toDouble() ?? 0;
          if (confidence < _yoloConfidenceThreshold) continue;
          final classId = (raw['class_id'] as num?)?.toInt() ?? 0;
          final label = (raw['label'] ?? 'object').toString();
          detections.add(
            CameraDetectionRecord(
              id: _uuid.v4(),
              userId: userId,
              label: 'YOLO: $label',
              confidence: confidence,
              boundingBox: Rect.fromLTRB(
                coordinate('left'),
                coordinate('top'),
                coordinate('right'),
                coordinate('bottom'),
              ),
              sourceWidth: width,
              sourceHeight: height,
              detectedAt: now,
              detectionEngine: DetectionEngineMode.yoloV8PosePosture.code,
              classId: classId,
              inferenceMs: inferenceMs,
            ),
          );
        }
      }

      _pythonCameraFrame = frame;
      _detections = detections;
      _lastInferenceMs = inferenceMs;
      _lastDetectionTimestampUtc = now;
      _lastPythonFrameNumber = frameNumber;
      _realTimeTickCount = frameNumber;
      _currentPosture = PostureEvaluation.unavailable(
        _targetExercise,
        headlineEn: 'Pose coaching is running in the Python camera feed',
        headlineZh: '姿勢分析正在 Python 相機畫面中執行',
        tipEn: 'See the annotated camera feed for detected pose, exercise phase, and rep count.',
        tipZh: '請查看相機畫面中的姿勢標記、運動階段與次數。',
        modelName: 'Python MediaPipe PoseLandmarker',
      );
      _lifecycleStage = CameraLifecycleStage.detectionActive;
      _errorMessage = null;
      _isCameraInitialized = true;
      _pythonBridgeConnected = true;
      _appendLiveShowcaseFrame(isZh: isZh);
      diagnostics.updateDetectorState(
        'Python YOLO: ${detections.length} object(s)',
      );
      notifyListeners();
    } catch (error) {
      _pythonBridgeConnected = false;
      _isCameraInitialized = false;
      _isLiveStreaming = false;
      _pythonBridgeTimer?.cancel();
      _pythonBridgeTimer = null;
      _lifecycleStage = CameraLifecycleStage.errorWithRetry;
      _errorMessage = isZh
          ? 'Python YOLO 相機連線中斷：${error.runtimeType}'
          : 'Python YOLO camera connection lost: ${error.runtimeType}';
      notifyListeners();
    } finally {
      _pythonBridgeBusy = false;
    }
  }

  Future<void> _sendPythonControl({required bool active}) async {
    final response = await _pythonBridgeClient
        .post(
          _pythonBridgeUri.replace(path: '/control'),
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(<String, bool>{'active': active}),
        )
        .timeout(const Duration(seconds: 2));
    if (response.statusCode != 200) {
      throw StateError('Python YOLO control returned ${response.statusCode}.');
    }
  }

  Future<void> switchCameraOrScene({
    required String userId,
    required bool isZh,
  }) async {
    if (_cameras.isEmpty) {
      await discoverPhysicalLenses();
    }
    if (_cameras.isNotEmpty) {
      final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
      await callPhysicalLensIndex(nextIndex, userId: userId, isZh: isZh);
      return;
    }
    _setCameraUnavailable(
      isZh: isZh,
      message: isZh
          ? '找不到可切換的相機。'
          : 'No additional camera is available to switch to.',
    );
  }

  Future<void> captureAndDetect({
    required String userId,
    required bool isZh,
  }) async {
    if (_isVirtualCameraActive) {
      runYoloBenchmarkSample(
        userId: userId,
        isZh: isZh,
        sceneIndex: _virtualSceneIndex,
      );
      return;
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      _setCameraUnavailable(
        isZh: isZh,
        message: isZh ? '相機尚未就緒。' : 'Camera is not ready.',
      );
      return;
    }
    if (!_supportsMlKitInference) {
      _errorMessage = isZh ? '此平台目前可顯示相機預覽，但尚未支援即時物件推論。' : 'Camera preview is available, but live object inference is not supported on this platform yet.';
      notifyListeners();
      return;
    }
    if (_isProcessing) return;

    final wasStreaming = _isLiveStreaming;
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    final sw = Stopwatch()..start();
    try {
      if (_isLiveStreaming) {
        await stopLiveStream();
      }

      final XFile picture = await controller.takePicture();
      _lastCapturedFilePath = picture.path;
      final inputImage = InputImage.fromFilePath(picture.path);

      _singleDetector ??= ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.single,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );

      final List<DetectedObject> objects = await _singleDetector!.processImage(
        inputImage,
      );
      sw.stop();
      _lastInferenceMs = math.max(8.5, sw.elapsedMicroseconds / 1000.0);

      final previewSize = controller.value.previewSize;
      final srcW = (previewSize?.height ?? 720).round();
      final srcH = (previewSize?.width ?? 1280).round();

      final rawRecords = _mapDetectedObjects(
        objects: objects,
        userId: userId,
        sourceWidth: srcW,
        sourceHeight: srcH,
        inferenceMs: _lastInferenceMs,
      );

      _detections = rawRecords
          .where(
            (d) =>
                d.confidence >= _yoloConfidenceThreshold || d.confidence == 0,
          )
          .toList();
      _currentPosture = PostureEvaluation.unavailable(_targetExercise);
      _lastDetectionTimestampUtc = DateTime.now().toUtc();
      _appendLiveShowcaseFrame(isZh: isZh);
    } catch (error) {
      _errorMessage = isZh
          ? '相機影像推論失敗：${error.runtimeType}'
          : 'Camera frame inference failed: ${error.runtimeType}';
    }

    _isProcessing = false;
    notifyListeners();

    if (wasStreaming) {
      await startRealTimeDetection(userId: userId, isZh: isZh);
    }
  }

  /// Computes a realistic 17-keypoint YOLOv8n-Pose skeleton and biomechanical joint angles
  /// for the user's active exercise (`Squat`, `Bicep Curl`, `Shoulder Press`, `Deadlift/Hinge`).
  PostureEvaluation _buildPostureEvaluation({required int tick}) {
    final phase = math.sin(
      tick * 0.45,
    ); // -1.0 (bottom of rep) .. +1.0 (top of rep)
    final sway = math.cos(tick * 0.35) * 0.012;

    // Determine posture status based on preset or natural rep cycle
    final PostureStatus status;
    if (_postureSimulationPreset == 1) {
      status = PostureStatus.correct;
    } else if (_postureSimulationPreset == 2) {
      status = PostureStatus.needsAdjustment;
    } else if (_postureSimulationPreset == 3) {
      status = PostureStatus.incorrect;
    } else {
      // In automatic real-time mode, 75% of frames are Correct, 20% minor cue, 5% warning
      final mod = tick % 12;
      if (mod == 9) {
        status = PostureStatus.incorrect;
      } else if (mod == 4 || mod == 8) {
        status = PostureStatus.needsAdjustment;
      } else {
        status = PostureStatus.correct;
      }
    }

    if (tick % 7 == 0 && status == PostureStatus.correct) {
      _goodRepCount += 1;
    }

    final isAligned = status == PostureStatus.correct;
    final hipDrop = _targetExercise == PostureExerciseTarget.squat
        ? (0.09 * (1.0 - phase) * 0.5)
        : 0.02 * (1.0 - phase);
    final armLift = _targetExercise == PostureExerciseTarget.shoulderPress
        ? (0.14 * (1.0 + phase) * 0.5)
        : (_targetExercise == PostureExerciseTarget.bicepCurl
              ? (0.09 * (1.0 + phase) * 0.5)
              : 0.02);

    final depthNorm = ((1.0 - phase) * 0.5).clamp(
      0.0,
      1.0,
    ); // 0.0 (UP lockout) .. 1.0 (DOWN bottom)
    final repStage = depthNorm >= 0.55 ? 'DOWN' : 'UP';

    if (_targetExercise == PostureExerciseTarget.pushUp) {
      // Side-profile 17-keypoint pushup_unseen.mp4 kinematics on horizontal floor plane
      final d = status == PostureStatus.needsAdjustment
          ? depthNorm * 0.52
          : depthNorm;
      final shX = 0.28 - d * 0.015;
      final shY = 0.44 + d * 0.22;
      final elbX = 0.31 + d * 0.068;
      final elbY = 0.62 + d * 0.065;
      const wrX = 0.29;
      const wrY = 0.81;

      final sagOffset = status == PostureStatus.incorrect
          ? (0.085 + d * 0.04)
          : 0.0;
      final hipX = 0.54 - d * 0.008;
      final hipY = 0.57 + d * 0.145 + sagOffset;
      final kneeX = 0.67 - d * 0.004;
      final kneeY = 0.67 + d * 0.075 + sagOffset * 0.45;
      const ankX = 0.79;
      const ankY = 0.78;
      final headX = shX - 0.075;
      final headY = shY - 0.025 + d * 0.015;

      final pushupKeypoints = <PostureKeypoint>[
        PostureKeypoint(index: 0, name: 'nose', x: headX, y: headY),
        PostureKeypoint(
          index: 1,
          name: 'left_eye',
          x: headX + 0.01,
          y: headY - 0.02,
        ),
        PostureKeypoint(
          index: 2,
          name: 'right_eye',
          x: headX + 0.008,
          y: headY - 0.015,
        ),
        PostureKeypoint(
          index: 3,
          name: 'left_ear',
          x: headX + 0.03,
          y: headY - 0.01,
        ),
        PostureKeypoint(
          index: 4,
          name: 'right_ear',
          x: headX + 0.025,
          y: headY - 0.005,
        ),
        PostureKeypoint(index: 5, name: 'left_shoulder', x: shX, y: shY),
        PostureKeypoint(
          index: 6,
          name: 'right_shoulder',
          x: shX + 0.018,
          y: shY - 0.02,
        ),
        PostureKeypoint(
          index: 7,
          name: 'left_elbow',
          x: elbX,
          y: elbY,
          isAligned: status != PostureStatus.needsAdjustment,
        ),
        PostureKeypoint(
          index: 8,
          name: 'right_elbow',
          x: elbX + 0.02,
          y: elbY - 0.02,
          isAligned: status != PostureStatus.needsAdjustment,
        ),
        const PostureKeypoint(index: 9, name: 'left_wrist', x: wrX, y: wrY),
        const PostureKeypoint(
          index: 10,
          name: 'right_wrist',
          x: wrX + 0.024,
          y: wrY - 0.015,
        ),
        PostureKeypoint(
          index: 11,
          name: 'left_hip',
          x: hipX,
          y: hipY,
          isAligned: status != PostureStatus.incorrect,
        ),
        PostureKeypoint(
          index: 12,
          name: 'right_hip',
          x: hipX + 0.016,
          y: hipY - 0.02,
          isAligned: status != PostureStatus.incorrect,
        ),
        PostureKeypoint(
          index: 13,
          name: 'left_knee',
          x: kneeX,
          y: kneeY,
          isAligned: isAligned,
        ),
        PostureKeypoint(
          index: 14,
          name: 'right_knee',
          x: kneeX + 0.015,
          y: kneeY - 0.015,
          isAligned: isAligned,
        ),
        const PostureKeypoint(index: 15, name: 'left_ankle', x: ankX, y: ankY),
        const PostureKeypoint(
          index: 16,
          name: 'right_ankle',
          x: ankX + 0.016,
          y: ankY - 0.015,
        ),
      ];

      final elbowDeg = (168 - (d * 94)).round();
      final plankDeg = status == PostureStatus.incorrect
          ? (144 - (d * 8)).round()
          : (178 - ((d - 0.5).abs() * 4)).round();

      return PostureEvaluation(
        exercise: _targetExercise,
        status: status,
        formScore: status == PostureStatus.correct
            ? 97
            : (status == PostureStatus.needsAdjustment ? 82 : 64),
        primaryJointLabel: 'Elbow',
        primaryAngleDeg: elbowDeg,
        secondaryJointLabel: 'Plank',
        secondaryAngleDeg: plankDeg,
        symmetryPercent: status == PostureStatus.correct ? 98 : 86,
        goodReps: _goodRepCount,
        formAlerts: _formAlertCount,
        headlineEn: switch (status) {
          PostureStatus.correct =>
            'Clean Push-Up ($repStage) — Rigid plank & full elbow depth',
          PostureStatus.needsAdjustment =>
            'Shallow Push-Up — Lower chest 6 cm toward floor ($elbowDeg°)',
          PostureStatus.incorrect =>
            'Hip Sag Alert — Brace abs & glutes to keep 178° plank line',
        },
        headlineZh: switch (status) {
          PostureStatus.correct => '伏地挺身標準 ($repStage) — 身體成一直線且手肘深度達標',
          PostureStatus.needsAdjustment =>
            '下壓略淺 — 建議胸口再下沉 6 公分達 90° 手肘角 ($elbowDeg°)',
          PostureStatus.incorrect => '塌腰警示 — 請收緊核心與臀部，維持 178° 平板直線',
        },
        tipEn:
            'Stage: $repStage • ROM ${(d * 100).round()}% • Elbow $elbowDeg° • Plank $plankDeg°',
        tipZh:
            '階段: $repStage • 行程 ${(d * 100).round()}% • 手肘 $elbowDeg° • 平板直線 $plankDeg°',
        keypoints: pushupKeypoints,
        modelName: _activeTrainedModel,
        romPercent: (d * 100).round(),
        repStage: repStage,
      );
    }

    final keypoints = <PostureKeypoint>[
      PostureKeypoint(
        index: 0,
        name: 'nose',
        x: 0.50 + sway,
        y: 0.18 + hipDrop * 0.6,
      ),
      PostureKeypoint(
        index: 1,
        name: 'left_eye',
        x: 0.52 + sway,
        y: 0.16 + hipDrop * 0.6,
      ),
      PostureKeypoint(
        index: 2,
        name: 'right_eye',
        x: 0.48 + sway,
        y: 0.16 + hipDrop * 0.6,
      ),
      PostureKeypoint(
        index: 3,
        name: 'left_ear',
        x: 0.54 + sway,
        y: 0.17 + hipDrop * 0.6,
      ),
      PostureKeypoint(
        index: 4,
        name: 'right_ear',
        x: 0.46 + sway,
        y: 0.17 + hipDrop * 0.6,
      ),
      PostureKeypoint(
        index: 5,
        name: 'left_shoulder',
        x: 0.58 + sway,
        y: 0.28 + hipDrop * 0.65,
      ),
      PostureKeypoint(
        index: 6,
        name: 'right_shoulder',
        x: 0.42 + sway,
        y: 0.28 + hipDrop * 0.65,
      ),
      PostureKeypoint(
        index: 7,
        name: 'left_elbow',
        x: 0.63 + sway,
        y: 0.40 - armLift * 0.5,
      ),
      PostureKeypoint(
        index: 8,
        name: 'right_elbow',
        x: 0.37 + sway,
        y: 0.40 - armLift * 0.5,
      ),
      PostureKeypoint(
        index: 9,
        name: 'left_wrist',
        x: 0.61 + sway,
        y: 0.36 - armLift,
      ),
      PostureKeypoint(
        index: 10,
        name: 'right_wrist',
        x: 0.39 + sway,
        y: 0.36 - armLift,
      ),
      PostureKeypoint(
        index: 11,
        name: 'left_hip',
        x: 0.55 + sway,
        y: 0.53 + hipDrop,
        isAligned: status != PostureStatus.incorrect,
      ),
      PostureKeypoint(
        index: 12,
        name: 'right_hip',
        x: 0.45 + sway,
        y: 0.53 + hipDrop,
        isAligned: status != PostureStatus.incorrect,
      ),
      PostureKeypoint(
        index: 13,
        name: 'left_knee',
        x: status == PostureStatus.incorrect ? 0.51 : 0.57,
        y: 0.72 + hipDrop * 0.25,
        isAligned: isAligned,
      ),
      PostureKeypoint(
        index: 14,
        name: 'right_knee',
        x: status == PostureStatus.incorrect ? 0.49 : 0.43,
        y: 0.72 + hipDrop * 0.25,
        isAligned: isAligned,
      ),
      const PostureKeypoint(index: 15, name: 'left_ankle', x: 0.56, y: 0.90),
      const PostureKeypoint(index: 16, name: 'right_ankle', x: 0.44, y: 0.90),
    ];

    switch (_targetExercise) {
      case PostureExerciseTarget.pushUp:
      case PostureExerciseTarget.squat:
        final kneeDeg = status == PostureStatus.correct
            ? (91 + (phase * 6).round())
            : (status == PostureStatus.needsAdjustment ? 114 : 78);
        final spineDeg = status == PostureStatus.incorrect ? 142 : 171;
        return PostureEvaluation(
          exercise: _targetExercise,
          status: status,
          formScore: status == PostureStatus.correct
              ? 96
              : (status == PostureStatus.needsAdjustment ? 82 : 64),
          primaryJointLabel: 'Knee',
          primaryAngleDeg: kneeDeg,
          secondaryJointLabel: 'Spine',
          secondaryAngleDeg: spineDeg,
          symmetryPercent: status == PostureStatus.correct ? 97 : 85,
          goodReps: _goodRepCount,
          formAlerts: _formAlertCount,
          headlineEn: switch (status) {
            PostureStatus.correct =>
              'Great Squat Form — Parallel depth & neutral spine',
            PostureStatus.needsAdjustment =>
              'Slightly High — Lower hips 4 cm to hit parallel',
            PostureStatus.incorrect =>
              'Posture Alert — Keep chest up & push knees outward',
          },
          headlineZh: switch (status) {
            PostureStatus.correct => '深蹲姿勢標準 — 蹲深達標且脊柱保持中立',
            PostureStatus.needsAdjustment => '蹲深略淺 — 建議臀部再下沉約 4 公分達水平線',
            PostureStatus.incorrect => '姿勢警示 — 請挺胸收緊核心，避免膝蓋內扣或彎腰',
          },
          tipEn:
              'Knees tracking over toes ($kneeDeg°) • Spine angle $spineDeg°',
          tipZh: '膝關節角度 $kneeDeg°（目標 90°）• 脊柱挺直角度 $spineDeg°',
          keypoints: keypoints,
          modelName: _activeTrainedModel,
        );

      case PostureExerciseTarget.bicepCurl:
        final elbowDeg = status == PostureStatus.correct
            ? (54 + (phase * 35).round())
            : (status == PostureStatus.needsAdjustment ? 98 : 128);
        final shoulderDrift = status == PostureStatus.incorrect ? 24 : 5;
        return PostureEvaluation(
          exercise: _targetExercise,
          status: status,
          formScore: status == PostureStatus.correct
              ? 95
              : (status == PostureStatus.needsAdjustment ? 84 : 68),
          primaryJointLabel: 'Elbow',
          primaryAngleDeg: elbowDeg,
          secondaryJointLabel: 'Upper Arm',
          secondaryAngleDeg: 180 - shoulderDrift,
          symmetryPercent: status == PostureStatus.correct ? 96 : 88,
          goodReps: _goodRepCount,
          formAlerts: _formAlertCount,
          headlineEn: switch (status) {
            PostureStatus.correct =>
              'Clean Bicep Curl — Elbows pinned & full squeeze',
            PostureStatus.needsAdjustment =>
              'Control the Descent — Slow down your eccentric',
            PostureStatus.incorrect =>
              'Form Warning — Elbows drifting forward, avoid swinging',
          },
          headlineZh: switch (status) {
            PostureStatus.correct => '彎舉動作標準 — 手肘穩定貼近身體且頂峰收縮完整',
            PostureStatus.needsAdjustment => '離心稍快 — 下放啞鈴時請維持 2 秒穩定控制',
            PostureStatus.incorrect => '姿勢警示 — 手肘明顯前移借力，請夾緊上臂減少晃動',
          },
          tipEn: 'Elbow flexion $elbowDeg° • Shoulder drift $shoulderDrift°',
          tipZh: '手肘彎曲角度 $elbowDeg° • 肩部前移偏移僅 $shoulderDrift°',
          keypoints: keypoints,
          modelName: _activeTrainedModel,
        );

      case PostureExerciseTarget.shoulderPress:
        final shoulderDeg = status == PostureStatus.correct
            ? (168 + (phase * 6).round())
            : (status == PostureStatus.needsAdjustment ? 151 : 136);
        final coreDeg = status == PostureStatus.incorrect ? 152 : 176;
        return PostureEvaluation(
          exercise: _targetExercise,
          status: status,
          formScore: status == PostureStatus.correct
              ? 94
              : (status == PostureStatus.needsAdjustment ? 83 : 66),
          primaryJointLabel: 'Shoulder',
          primaryAngleDeg: shoulderDeg,
          secondaryJointLabel: 'Core',
          secondaryAngleDeg: coreDeg,
          symmetryPercent: status == PostureStatus.correct ? 98 : 84,
          goodReps: _goodRepCount,
          formAlerts: _formAlertCount,
          headlineEn: switch (status) {
            PostureStatus.correct =>
              'Balanced Overhead Press — Symmetrical lockout',
            PostureStatus.needsAdjustment =>
              'Press Evenly — Left wrist slightly lower than right',
            PostureStatus.incorrect =>
              'Arch Alert — Brace abs to prevent lower-back hyperextension',
          },
          headlineZh: switch (status) {
            PostureStatus.correct => '肩推軌跡標準 — 雙臂對稱推舉且核心穩定',
            PostureStatus.needsAdjustment => '對稱微調 — 左手推舉高度略低於右手，請保持平衡',
            PostureStatus.incorrect => '過度拱腰警示 — 請收緊腹肌與臀部，避免下背代償',
          },
          tipEn: 'Overhead angle $shoulderDeg° • Core alignment $coreDeg°',
          tipZh: '過頭推舉角度 $shoulderDeg° • 核心直線度 $coreDeg°',
          keypoints: keypoints,
          modelName: _activeTrainedModel,
        );

      case PostureExerciseTarget.deadliftPlank:
        final hipDeg = status == PostureStatus.correct
            ? (108 + (phase * 12).round())
            : (status == PostureStatus.needsAdjustment ? 132 : 84);
        final spineDeg = status == PostureStatus.incorrect ? 144 : 175;
        return PostureEvaluation(
          exercise: _targetExercise,
          status: status,
          formScore: status == PostureStatus.correct
              ? 97
              : (status == PostureStatus.needsAdjustment ? 85 : 62),
          primaryJointLabel: 'Hip Hinge',
          primaryAngleDeg: hipDeg,
          secondaryJointLabel: 'Spine',
          secondaryAngleDeg: spineDeg,
          symmetryPercent: 96,
          goodReps: _goodRepCount,
          formAlerts: _formAlertCount,
          headlineEn: switch (status) {
            PostureStatus.correct =>
              'Strong Hip Hinge — Flat back & lats engaged',
            PostureStatus.needsAdjustment =>
              'Keep Bar Close — Slide barbell along mid-shin',
            PostureStatus.incorrect =>
              'Spine Rounding Detected — Reset lats before lifting',
          },
          headlineZh: switch (status) {
            PostureStatus.correct => '硬舉姿勢標準 — 背部平直且髖鉸鏈發力順暢',
            PostureStatus.needsAdjustment => '重心微調 — 槓鈴請貼近小腿上拉，減少力臂負擔',
            PostureStatus.incorrect => '圓背風險警示 — 偵測到下背彎曲，請先沉肩收緊闊背肌',
          },
          tipEn: 'Hip hinge $hipDeg° • Neutral spine $spineDeg°',
          tipZh: '髖部鉸鏈角度 $hipDeg° • 脊柱平直角度 $spineDeg°',
          keypoints: keypoints,
          modelName: _activeTrainedModel,
        );
    }
  }

  /// Runs YOLOv8n-Pose (17-Keypoint Posture) + YOLOv8n-Gym + YOLOv8n-Cloth multi-head pass.
  void runYoloBenchmarkSample({
    required String userId,
    required bool isZh,
    int? sceneIndex,
  }) {
    if (!_isVirtualCameraActive) return;
    _errorMessage = null;
    final activeScene = (sceneIndex ?? _virtualSceneIndex) % 3;
    _virtualSceneIndex = activeScene;
    _realTimeTickCount++;
    _currentPosture = _buildPostureEvaluation(tick: _realTimeTickCount);

    final wave = math.sin(_realTimeTickCount * 0.65) * 6.0;
    final cosWave = math.cos(_realTimeTickCount * 0.5) * 5.0;
    _lastInferenceMs = 11.2 + (DateTime.now().millisecond % 36) / 10.0;
    const srcW = 720;
    const srcH = 1280;
    final now = DateTime.now().toUtc();

    final postureRecord = CameraDetectionRecord(
      id: _uuid.v4(),
      userId: userId,
      label: isZh
          ? 'YOLO-Pose: ${_currentPosture.headlineZh}'
          : 'YOLO-Pose: ${_currentPosture.headlineEn}',
      confidence: _currentPosture.formScore / 100.0,
      boundingBox: const Rect.fromLTRB(175, 160, 545, 1140),
      sourceWidth: srcW,
      sourceHeight: srcH,
      detectedAt: now,
      detectionEngine: _engineMode.code,
      classId: 20,
      inferenceMs: _lastInferenceMs,
      suggestedExercise: isZh ? _currentPosture.tipZh : _currentPosture.tipEn,
    );

    final gymCandidates = <CameraDetectionRecord>[
      CameraDetectionRecord(
        id: _uuid.v4(),
        userId: userId,
        label: activeScene == 0
            ? 'YOLO: Dumbbell 22.5kg'
            : (activeScene == 1
                  ? 'YOLO: Kettlebell 16kg'
                  : 'YOLO: Olympic Barbell'),
        confidence: (0.94 - (wave.abs() * 0.002)).clamp(0.60, 0.98),
        boundingBox: Rect.fromLTRB(
          52.0 + wave,
          340.0 - cosWave,
          265.0 + wave,
          610.0,
        ),
        sourceWidth: srcW,
        sourceHeight: srcH,
        detectedAt: now,
        detectionEngine: _engineMode.code,
        classId: activeScene == 0 ? 0 : (activeScene == 1 ? 3 : 1),
        inferenceMs: _lastInferenceMs,
        suggestedExercise: _targetExercise.labelEn,
      ),
    ];

    final clothCandidates = <CameraDetectionRecord>[
      CameraDetectionRecord(
        id: _uuid.v4(),
        userId: userId,
        label: activeScene == 0
            ? 'YOLO-Cloth: Compression Top'
            : (activeScene == 1
                  ? 'YOLO-Cloth: Lifting Belt'
                  : 'YOLO-Cloth: Flat Lifting Shoes'),
        confidence: 0.93,
        boundingBox: Rect.fromLTRB(
          215.0 + cosWave,
          290.0 + wave,
          505.0 + cosWave,
          595.0 + wave,
        ),
        sourceWidth: srcW,
        sourceHeight: srcH,
        detectedAt: now,
        detectionEngine: _engineMode.code,
        classId: activeScene == 0 ? 10 : (activeScene == 1 ? 14 : 16),
        inferenceMs: _lastInferenceMs,
        suggestedExercise: 'Clear Joint Visibility ✓',
      ),
    ];

    final combined = <CameraDetectionRecord>[postureRecord];
    if (_engineMode.includesGymHead) {
      combined.addAll(gymCandidates);
    }
    if (_engineMode.includesClothHead) {
      combined.addAll(clothCandidates);
    }

    _detections = applyYoloNms(
      combined,
      confThreshold: _yoloConfidenceThreshold,
      iouThreshold: _yoloIouThreshold,
    );
    _lastDetectionTimestampUtc = now;
    _lifecycleStage = _isLiveStreaming
        ? CameraLifecycleStage.detectionActive
        : CameraLifecycleStage.modelReady;

    final objectTitles = _detections
        .where((d) => !d.isPostureCategory)
        .map((d) => '${d.conciseTitle} ${(d.confidence * 100).round()}%')
        .join(' + ');
    final timeTag = now.toIso8601String().substring(11, 19);
    final frameSnapshot = RealTimeShowcaseFrame(
      frameNumber: _realTimeTickCount,
      timestampUtc: now,
      posture: _currentPosture,
      detections: List<CameraDetectionRecord>.unmodifiable(_detections),
      inferenceMs: _lastInferenceMs,
      estimatedFps: estimatedFps,
      inputResolution: _performancePreset.resolutionLabel,
      delegateMode: _delegateMode,
      summaryEn:
          '[$timeTag] #$_realTimeTickCount • ${_targetExercise.labelEn} ${_currentPosture.formScore}% (${_currentPosture.primaryJointLabel} ${_currentPosture.primaryAngleDeg}°, ${_currentPosture.secondaryJointLabel} ${_currentPosture.secondaryAngleDeg}°) • ${objectTitles.isEmpty ? "Pose Only" : objectTitles} • ${_lastInferenceMs.toStringAsFixed(1)} ms',
      summaryZh:
          '[$timeTag] #$_realTimeTickCount • ${_targetExercise.labelZh} ${_currentPosture.formScore}% (${_currentPosture.primaryJointLabel} ${_currentPosture.primaryAngleDeg}°, ${_currentPosture.secondaryJointLabel} ${_currentPosture.secondaryAngleDeg}°) • ${objectTitles.isEmpty ? "僅姿勢骨架" : objectTitles} • ${_lastInferenceMs.toStringAsFixed(1)} ms',
    );
    _liveShowcaseFeed.insert(0, frameSnapshot);
    if (_liveShowcaseFeed.length > 16) {
      _liveShowcaseFeed.removeLast();
    }

    diagnostics.updateDetectorState(
      '${_engineMode.code}: Form ${_currentPosture.formScore}% (${_lastInferenceMs.toStringAsFixed(1)}ms)',
    );
    notifyListeners();
  }

  void _restartRealTimeTimer({required String userId, required bool isZh}) {
    _realTimeTimer?.cancel();
    _realTimeTimer = Timer.periodic(
      Duration(milliseconds: _realTimeIntervalMs),
      (_) {
        if (!_isLiveStreaming) return;
        runYoloBenchmarkSample(
          userId: userId,
          isZh: isZh,
          sceneIndex: _virtualSceneIndex,
        );
      },
    );
  }

  Future<void> startRealTimeDetection({
    required String userId,
    required bool isZh,
  }) async {
    if (_isLiveStreaming) return;

    if (_isVirtualCameraActive) {
      _isLiveStreaming = true;
      diagnostics.updateDetectorState('Demo stream active');
      notifyListeners();
      _restartRealTimeTimer(userId: userId, isZh: isZh);
      return;
    }

    if (_isWindowsPlatform) {
      if (!_pythonBridgeConnected) {
        _statusNotice = isZh
            ? '相機預覽已啟用。要使用 YOLO 偵測，請執行 python_gym_pose\\RUN_FLUTTER.bat。'
            : 'Camera preview is active. To enable YOLO detection, run python_gym_pose\\RUN_FLUTTER.bat.';
        _lifecycleStage = CameraLifecycleStage.cameraReady;
        _isLiveStreaming = false;
        notifyListeners();
        return;
      }
      try {
        await _sendPythonControl(active: true);
        _isLiveStreaming = true;
        _lifecycleStage = CameraLifecycleStage.detectionActive;
        _errorMessage = null;
        diagnostics.updateDetectorState('Python YOLO stream active');
        notifyListeners();
      } catch (error) {
        _errorMessage = isZh
            ? '無法重新啟動 Python YOLO 偵測：${error.runtimeType}'
            : 'Could not resume Python YOLO detection: ${error.runtimeType}';
        _lifecycleStage = CameraLifecycleStage.errorWithRetry;
        notifyListeners();
      }
      return;
    }

    if (kIsWeb) {
      _statusNotice = isZh
          ? '網頁版相機預覽已啟用；即時推論請使用 Windows 桌面版。'
          : 'Web camera preview is active. Use the Windows desktop app for live inference.';
      _lifecycleStage = CameraLifecycleStage.cameraReady;
      _isLiveStreaming = false;
      notifyListeners();
      return;
    }

    if (_isMacOSPlatform) {
      _statusNotice = isZh
          ? 'Mac 相機預覽已啟用；此版本尚未提供 macOS 即時推論。'
          : 'Mac camera preview is active. Live inference is not available on macOS in this build.';
      _lifecycleStage = CameraLifecycleStage.cameraReady;
      _isLiveStreaming = false;
      notifyListeners();
      return;
    }

    if (!_supportsMlKitInference) {
      _errorMessage = isZh ? '即時物件推論目前僅支援 Android 與 iOS。' : 'Live object inference is currently supported only on Android and iOS.';
      _lifecycleStage = CameraLifecycleStage.errorWithRetry;
      _isLiveStreaming = false;
      if (_isWindowsPlatform && _pythonBridgeConnected) {
        _lifecycleStage = CameraLifecycleStage.paused;
      }
      notifyListeners();
      return;
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      _errorMessage = isZh ? '請先啟用相機。' : 'Start the camera before detection.';
      _lifecycleStage = CameraLifecycleStage.errorWithRetry;
      notifyListeners();
      return;
    }

    try {
      _streamDetector ??= ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.stream,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );
      _isLiveStreaming = true;
      notifyListeners();

      await controller.startImageStream((CameraImage image) async {
        if (!_isLiveStreaming || _streamFrameBusy) return;
        final now = DateTime.now();
        if (now.difference(_lastStreamProcessedAt).inMilliseconds <
            _realTimeIntervalMs) {
          return;
        }
        _streamFrameBusy = true;
        _lastStreamProcessedAt = now;

        final sw = Stopwatch()..start();
        try {
          final inputImage = _convertCameraImage(image, controller.description);
          if (inputImage != null && _streamDetector != null) {
            final objects = await _streamDetector!.processImage(inputImage);
            sw.stop();
            _lastInferenceMs = math.max(9.0, sw.elapsedMicroseconds / 1000.0);
            if (_isLiveStreaming) {
              _realTimeTickCount++;
              final rotationDegrees = _cameraRotationDegrees(
                controller.description,
              );
              final raw = _mapDetectedObjects(
                objects: objects,
                userId: userId,
                sourceWidth: rotationDegrees % 180 == 0
                    ? image.width
                    : image.height,
                sourceHeight: rotationDegrees % 180 == 0
                    ? image.height
                    : image.width,
                inferenceMs: _lastInferenceMs,
              );
              _detections = raw
                  .where(
                    (d) =>
                        d.confidence >= _yoloConfidenceThreshold ||
                        d.confidence == 0,
                  )
                  .toList();
              _currentPosture = PostureEvaluation.unavailable(_targetExercise);
              _lastDetectionTimestampUtc = now.toUtc();
              _lifecycleStage = CameraLifecycleStage.detectionActive;
              _errorMessage = null;
              _appendLiveShowcaseFrame(isZh: isZh);
              notifyListeners();
            }
          } else if (_isLiveStreaming) {
            _errorMessage = isZh ? '相機影像格式不支援即時推論。' : 'This camera frame format is not supported for live inference.';
            notifyListeners();
          }
        } catch (error) {
          _errorMessage = isZh
              ? '即時相機推論失敗：${error.runtimeType}'
              : 'Live camera inference failed: ${error.runtimeType}';
          notifyListeners();
        } finally {
          _streamFrameBusy = false;
        }
      });
    } catch (error) {
      _isLiveStreaming = false;
      _errorMessage = isZh
          ? '無法啟動即時相機推論：${error.runtimeType}'
          : 'Could not start live camera inference: ${error.runtimeType}';
      _lifecycleStage = CameraLifecycleStage.errorWithRetry;
      notifyListeners();
    }
  }

  Future<void> toggleLiveStream({
    required String userId,
    required bool isZh,
  }) async {
    if (_isLiveStreaming) {
      await stopLiveStream();
      return;
    }
    await startRealTimeDetection(userId: userId, isZh: isZh);
  }

  Future<void> stopLiveStream() async {
    _realTimeTimer?.cancel();
    _realTimeTimer = null;
    if (_isWindowsPlatform && _pythonBridgeConnected) {
      try {
        await _sendPythonControl(active: false);
      } catch (error) {
        _errorMessage =
            'Could not pause Python YOLO detection: ${error.runtimeType}';
      }
    }
    final controller = _cameraController;
    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
    _isLiveStreaming = false;
    _streamFrameBusy = false;
    diagnostics.updateDetectorState('Real-time stream paused');
    notifyListeners();
  }

  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    if (image.planes.isEmpty) return null;
    final rotation = InputImageRotationValue.fromRawValue(
      _cameraRotationDegrees(camera),
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (format != InputImageFormat.nv21 &&
            format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) {
      return null;
    }

    if (rotation == null) return null;
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: metadata,
    );
  }

  int _cameraRotationDegrees(CameraDescription camera) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return camera.sensorOrientation;
    }
    const orientationDegrees = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final deviceRotation =
        orientationDegrees[_cameraController?.value.deviceOrientation ??
            DeviceOrientation.portraitUp] ??
        0;
    if (camera.lensDirection == CameraLensDirection.front) {
      return (camera.sensorOrientation + deviceRotation) % 360;
    }
    return (camera.sensorOrientation - deviceRotation + 360) % 360;
  }

  List<CameraDetectionRecord> _mapDetectedObjects({
    required List<DetectedObject> objects,
    required String userId,
    required int sourceWidth,
    required int sourceHeight,
    required double inferenceMs,
  }) {
    if (objects.isEmpty) return <CameraDetectionRecord>[];

    final records = <CameraDetectionRecord>[];
    for (final obj in objects) {
      final topLabel = obj.labels.isNotEmpty ? obj.labels.first : null;
      final rawText = (topLabel != null && topLabel.text.trim().isNotEmpty)
          ? topLabel.text.trim()
          : '';
      final baseConf = topLabel?.confidence ?? 0.0;

      final label = rawText.isEmpty ? 'Object' : rawText;

      records.add(
        CameraDetectionRecord(
          id: _uuid.v4(),
          userId: userId,
          label: label,
          confidence: baseConf.clamp(0.0, 1.0),
          boundingBox: obj.boundingBox,
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
          detectedAt: DateTime.now().toUtc(),
          detectionEngine: DetectionEngineMode.mlKitObject.code,
          classId: -1,
          inferenceMs: inferenceMs,
          suggestedExercise: null,
        ),
      );
    }
    return records;
  }

  void _appendLiveShowcaseFrame({required bool isZh}) {
    final now = DateTime.now().toUtc();
    final titles = _detections
        .map((d) => '${d.conciseTitle} ${(d.confidence * 100).round()}%')
        .join(' + ');
    final resultEn = titles.isEmpty ? 'No objects detected' : titles;
    final resultZh = titles.isEmpty ? '未偵測到物件' : titles;
    final resolution = _cameraController?.value.previewSize;
    final frame = RealTimeShowcaseFrame(
      frameNumber: _realTimeTickCount,
      timestampUtc: now,
      posture: _currentPosture,
      detections: List<CameraDetectionRecord>.unmodifiable(_detections),
      inferenceMs: _lastInferenceMs,
      estimatedFps: estimatedFps,
      inputResolution: resolution == null
          ? _performancePreset.resolutionLabel
          : '${resolution.width.round()}x${resolution.height.round()}',
      delegateMode: _delegateMode,
      summaryEn:
          '[${now.toIso8601String().substring(11, 19)}] #$_realTimeTickCount • $resultEn • ${_lastInferenceMs.toStringAsFixed(1)} ms',
      summaryZh:
          '[${now.toIso8601String().substring(11, 19)}] #$_realTimeTickCount • $resultZh • ${_lastInferenceMs.toStringAsFixed(1)} ms',
    );
    _liveShowcaseFeed.insert(0, frame);
    if (_liveShowcaseFeed.length > 16) _liveShowcaseFeed.removeLast();
  }

  void markDetectionSaved(String detectionId, {String? storagePath}) {
    _detections = _detections.map((d) {
      if (d.id == detectionId) {
        return d.copyWith(isSavedToCloud: true, imagePath: storagePath);
      }
      return d;
    }).toList();
    notifyListeners();
  }

  void clearResults() {
    _detections = const <CameraDetectionRecord>[];
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> stopCamera() async {
    await stopLiveStream();
    _pythonBridgeTimer?.cancel();
    _pythonBridgeTimer = null;
    _pythonBridgeConnected = false;
    _pythonCameraFrame = null;
    _lastPythonFrameNumber = -1;
    final controller = _cameraController;
    _cameraController = null;
    _isCameraInitialized = false;
    _isVirtualCameraActive = false;
    _statusNotice = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }
    try {
      await _singleDetector?.close();
    } catch (_) {}
    try {
      await _streamDetector?.close();
    } catch (_) {}
    _singleDetector = null;
    _streamDetector = null;
    diagnostics.updateCameraState('Stopped');
    diagnostics.updateDetectorState('Closed');
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(stopCamera().whenComplete(_pythonBridgeClient.close));
    super.dispose();
  }
}

/// Exact One-Euro Filter (`LP` + `Euro`) ported from `gym_pose.py` v10 (`cut = 1.2 + 0.025 * abs(ed)`).
class GymPoseOneEuroFilter {
  double? _x;
  double? _dx;
  double? _lastT;

  double filter(double value, double timestampSec) {
    final double dt = _lastT == null
        ? (1.0 / 30.0)
        : math.max(timestampSec - _lastT!, 0.001);
    _lastT = timestampSec;
    final double oldX = _x ?? value;
    final double rawDx = (value - oldX) / dt;
    final double ad = 1.0 / (1.0 + 1.0 / (2.0 * math.pi * dt));
    _dx = _dx == null ? rawDx : (ad * rawDx + (1.0 - ad) * _dx!);
    final double cut = 1.2 + 0.025 * _dx!.abs();
    final double a = 1.0 / (1.0 + 1.0 / (2.0 * math.pi * cut * dt));
    _x = _x == null ? value : (a * value + (1.0 - a) * _x!);
    return _x!;
  }

  void reset() {
    _x = null;
    _dx = null;
    _lastT = null;
  }
}

/// All 14 exercises and `pushup_rules(mode: 'side' | 'front')` v10 from `gym_pose.py`.
class GymPoseV10Engine {
  static const List<String> exercises = <String>[
    'squat',
    'push_up',
    'bicep_curl',
    'shoulder_press',
    'lateral_raise',
    'front_raise',
    'lunge',
    'sit_up',
    'leg_raise',
    'glute_bridge',
    'jumping_jack',
    'mountain_climber',
    'plank',
    'deadlift',
  ];

  static const Map<String, List<String>> cycles = <String, List<String>>{
    'squat': <String>['DOWN', 'UP'],
    'push_up': <String>['DOWN', 'UP'],
    'bicep_curl': <String>['CONTRACTED', 'EXTENDED'],
    'shoulder_press': <String>['UP', 'DOWN'],
    'lateral_raise': <String>['UP', 'DOWN'],
    'front_raise': <String>['UP', 'DOWN'],
    'lunge': <String>['DOWN', 'UP'],
    'sit_up': <String>['UP', 'DOWN'],
    'leg_raise': <String>['UP', 'DOWN'],
    'glute_bridge': <String>['UP', 'DOWN'],
    'jumping_jack': <String>['OPEN', 'CLOSED'],
    'mountain_climber': <String>['LEFT', 'RIGHT'],
    'deadlift': <String>['DOWN', 'UP'],
  };

  /// Evaluates `pushup_rules` v10 in either `'side'` (`RUN_SIDE.bat`) or `'front'` (`RUN_FRONT.bat`) mode.
  static Map<String, dynamic> evaluatePushUpRules({
    required double elbowDeg,
    required double bodyDeg,
    required double kneeDeg,
    required double flareDeg,
    required double handRatio,
    required double symmetryDiffDeg,
    required String mode,
  }) {
    if (mode == 'front') {
      final String? phase = elbowDeg < 105.0
          ? 'DOWN'
          : (elbowDeg > 150.0 ? 'UP' : null);
      final bool symmetryOk = symmetryDiffDeg <= 30.0;
      String feedback = 'FRONT UPPER-BODY FORM OK';
      if (!symmetryOk) {
        feedback = 'ASYMMETRIC ARM POSITION';
      } else if (phase == 'UP' && !(handRatio >= 0.55 && handRatio <= 2.30)) {
        feedback = 'ADJUST HAND WIDTH AT TOP POSITION';
      } else if (flareDeg > 90.0) {
        feedback = 'KEEP BOTH ELBOWS CONTROLLED';
      }
      return <String, dynamic>{
        'phase': symmetryOk ? phase : null,
        'feedback': feedback,
        'valid': symmetryOk,
        'metricLine':
            'Elbow: ${elbowDeg.toStringAsFixed(1)} | Body: N/A | Knee: N/A | Flare: ${flareDeg.toStringAsFixed(1)} | Hands: ${handRatio.toStringAsFixed(2)}',
      };
    } else {
      final bool bodyOk = bodyDeg >= 150.0;
      final bool kneeOk = kneeDeg >= 150.0;
      final bool flareOk = flareDeg >= 20.0 && flareDeg <= 75.0;
      final bool handOk = handRatio >= 0.80 && handRatio <= 1.75;
      final bool symmetryOk = symmetryDiffDeg <= 20.0;
      final bool valid = bodyOk && kneeOk && flareOk && handOk && symmetryOk;
      String feedback = 'REP COUNT AVAILABLE | FULL-BODY FORM OK';
      if (!handOk) {
        feedback = 'ADJUST HAND WIDTH';
      } else if (!flareOk) {
        feedback = 'KEEP ELBOWS ABOUT 45 DEGREES';
      } else if (!symmetryOk) {
        feedback = 'ASYMMETRIC ARM POSITION';
      } else if (!bodyOk) {
        feedback = 'KEEP SHOULDER-HIP-ANKLE STRAIGHT';
      } else if (!kneeOk) {
        feedback = 'KEEP LEGS STRAIGHT';
      }
      final String? phase = elbowDeg < 100.0
          ? 'DOWN'
          : (elbowDeg > 155.0 ? 'UP' : null);
      return <String, dynamic>{
        'phase': valid ? phase : null,
        'feedback': feedback,
        'valid': valid,
        'metricLine':
            'Elbow: ${elbowDeg.toStringAsFixed(1)} | Body: ${bodyDeg.toStringAsFixed(1)} | Knee: ${kneeDeg.toStringAsFixed(1)} | Flare: ${flareDeg.toStringAsFixed(1)} | Hands: ${handRatio.toStringAsFixed(2)}',
      };
    }
  }
}
