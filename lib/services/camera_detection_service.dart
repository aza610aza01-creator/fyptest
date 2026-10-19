import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';

/// Real Android camera and Google ML Kit general object detection service.
/// Supports:
/// 1) Capture-based detection (default stable flow: Preview -> Capture XFile ->
///    InputImage -> ML Kit ObjectDetector -> Results -> Save to Supabase)
/// 2) Optional throttled live stream detection (single frame at a time,
///    400ms throttle, automatic stream stop before capture or on pause/dispose).
class CameraDetectionService extends ChangeNotifier {
  CameraDetectionService({required this.diagnostics});

  final DiagnosticsService diagnostics;
  final Uuid _uuid = const Uuid();

  CameraController? _cameraController;
  ObjectDetector? _singleDetector;
  ObjectDetector? _streamDetector;

  List<CameraDescription> _cameras = const <CameraDescription>[];
  List<CameraDetectionRecord> _detections = const <CameraDetectionRecord>[];

  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isLiveStreaming = false;
  bool _streamFrameBusy = false;
  DateTime _lastStreamProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _errorMessage;
  String? _lastCapturedFilePath;

  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isProcessing => _isProcessing;
  bool get isLiveStreaming => _isLiveStreaming;
  List<CameraDetectionRecord> get detections => List.unmodifiable(_detections);
  String? get errorMessage => _errorMessage;
  String? get lastCapturedFilePath => _lastCapturedFilePath;

  /// Initializes the rear Android camera and ML Kit ObjectDetector.
  Future<void> startCamera({bool isZh = false}) async {
    _errorMessage = null;
    _isProcessing = true;
    notifyListeners();

    try {
      await stopCamera();

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _errorMessage = isZh
            ? '未在此裝置偵測到可用相機硬體。'
            : 'No camera hardware found on this device.';
        diagnostics.updateCameraState('Error: No camera hardware');
        _isProcessing = false;
        notifyListeners();
        return;
      }

      final selectedCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      _cameraController = controller;
      _isCameraInitialized = true;

      _singleDetector = ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.single,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );

      diagnostics.updateCameraState(
        'Ready (${selectedCamera.name}, ${ResolutionPreset.medium.name})',
      );
      diagnostics.updateDetectorState('Ready (DetectionMode.single)');
    } on CameraException catch (e) {
      if (e.code.toLowerCase().contains('access') ||
          e.code.toLowerCase().contains('permission')) {
        _errorMessage = isZh
            ? '相機權限遭拒絕，請於 Android 系統設定中允許相機權限後重試。'
            : 'Camera permission denied. Please grant Android camera access and retry.';
      } else {
        _errorMessage = '${e.code}: ${e.description ?? "Camera error"}';
      }
      diagnostics.updateCameraState('CameraException (${e.code})');
    } catch (e) {
      _errorMessage = isZh
          ? '初始化相機失敗（${e.runtimeType}）。請確認在實體 Android 裝置上執行。'
          : 'Failed to initialize camera (${e.runtimeType}). Ensure you are running on an Android device.';
      diagnostics.updateCameraState('Failed (${e.runtimeType})');
    }

    _isProcessing = false;
    notifyListeners();
  }

  /// Primary Capture-and-Detect workflow:
  /// Stops any live image stream -> Captures XFile -> Converts to InputImage ->
  /// Processes with ML Kit -> Updates detection list & bounding boxes.
  Future<void> captureAndDetect({
    required String userId,
    required bool isZh,
  }) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      _errorMessage = isZh ? '請先啟動相機。' : 'Please start the camera first.';
      notifyListeners();
      return;
    }
    if (_isProcessing) return;

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

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

      diagnostics.updateDetectorState('Processing captured XFile...');
      final List<DetectedObject> objects =
          await _singleDetector!.processImage(inputImage);

      final previewSize = controller.value.previewSize;
      final srcW = (previewSize?.height ?? 720).round();
      final srcH = (previewSize?.width ?? 1280).round();

      _detections = _mapDetectedObjects(
        objects: objects,
        userId: userId,
        sourceWidth: srcW,
        sourceHeight: srcH,
      );

      diagnostics.updateDetectorState(
        'Completed (${_detections.length} objects detected)',
      );
    } on CameraException catch (e) {
      _errorMessage = '${e.code}: ${e.description ?? "Capture failed"}';
      diagnostics.updateCameraState('Capture error (${e.code})');
    } catch (e) {
      _errorMessage = isZh
          ? 'ML Kit 影像偵測失敗（${e.runtimeType}）。'
          : 'ML Kit object detection failed (${e.runtimeType}).';
      diagnostics.updateDetectorState('Error (${e.runtimeType})');
    }

    _isProcessing = false;
    notifyListeners();
  }

  /// Optional throttled live stream detection (350-450ms throttle, 1 frame at a time).
  Future<void> toggleLiveStream({
    required String userId,
    required bool isZh,
  }) async {
    if (_isLiveStreaming) {
      await stopLiveStream();
      return;
    }
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      _streamDetector ??= ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.stream,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );
      _isLiveStreaming = true;
      diagnostics.updateDetectorState('Live Stream Active (400ms throttle)');
      notifyListeners();

      await controller.startImageStream((CameraImage image) async {
        if (!_isLiveStreaming || _streamFrameBusy) return;
        final now = DateTime.now();
        if (now.difference(_lastStreamProcessedAt).inMilliseconds < 400) {
          return;
        }
        _streamFrameBusy = true;
        _lastStreamProcessedAt = now;

        try {
          final inputImage = _convertCameraImage(image, controller.description);
          if (inputImage != null && _streamDetector != null) {
            final objects = await _streamDetector!.processImage(inputImage);
            if (_isLiveStreaming) {
              _detections = _mapDetectedObjects(
                objects: objects,
                userId: userId,
                sourceWidth: image.width,
                sourceHeight: image.height,
              );
              notifyListeners();
            }
          }
        } catch (_) {
          // Drop malformed stream frame safely
        } finally {
          _streamFrameBusy = false;
        }
      });
    } catch (e) {
      _isLiveStreaming = false;
      _errorMessage = isZh
          ? '無法啟動即時串流，請使用拍照偵測模式。'
          : 'Could not start image stream; use Capture & Detect mode.';
      notifyListeners();
    }
  }

  Future<void> stopLiveStream() async {
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
    diagnostics.updateDetectorState('Live stream stopped');
    notifyListeners();
  }

  InputImage? _convertCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    if (image.planes.isEmpty) return null;
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation90deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  List<CameraDetectionRecord> _mapDetectedObjects({
    required List<DetectedObject> objects,
    required String userId,
    required int sourceWidth,
    required int sourceHeight,
  }) {
    if (objects.isEmpty) return <CameraDetectionRecord>[];

    final records = <CameraDetectionRecord>[];
    for (final obj in objects) {
      final topLabel = obj.labels.isNotEmpty ? obj.labels.first : null;
      final labelText = (topLabel != null && topLabel.text.trim().isNotEmpty)
          ? topLabel.text.trim()
          : 'Detected Object #${obj.trackingId ?? records.length + 1}';
      final confidence = topLabel != null ? topLabel.confidence : 0.65;

      records.add(
        CameraDetectionRecord(
          id: _uuid.v4(),
          userId: userId,
          label: labelText,
          confidence: confidence.clamp(0.0, 1.0),
          boundingBox: obj.boundingBox,
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
          detectedAt: DateTime.now().toUtc(),
        ),
      );
    }
    return records;
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

  /// Stops camera preview, live stream, and closes ML Kit detectors cleanly.
  Future<void> stopCamera() async {
    await stopLiveStream();
    final controller = _cameraController;
    _cameraController = null;
    _isCameraInitialized = false;
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
  void dispose() {
    stopCamera();
    super.dispose();
  }
}
