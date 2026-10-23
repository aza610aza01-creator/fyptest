import 'dart:ui';

/// Supported AI computer-vision engines in AI Gym Cloud.
/// Includes Pre-Trained YOLOv8n-Pose (17-Keypoint Real-Time Posture & Form Coach),
/// YOLOv8n Multi-Head (Gym Equipment + Cloth), YOLOv8n-Cloth, YOLOv8n-Gym, and ML Kit.
enum DetectionEngineMode {
  yoloV8PosePosture(
    'yolov8n_pose',
    'YOLOv8n-Pose (Trained 17-Keypoint Posture + Gym & Cloth)',
  ),
  yoloV8GymClothMulti(
    'yolov8_gym_cloth',
    'YOLOv8n Multi-Head (Gym Equipment + Sportswear)',
  ),
  yoloV8Cloth(
    'yolov8_cloth',
    'YOLOv8n-Cloth (Sportswear & Lifting Gear)',
  ),
  yoloV8Gym(
    'yolov8_gym',
    'YOLOv8n-Gym (Equipment Classifier)',
  ),
  yoloHybrid(
    'yolo_mlkit_hybrid',
    'YOLOv8 + ML Kit Hybrid Pipeline',
  ),
  mlKitObject(
    'mlkit_object',
    'Google ML Kit Object Detector',
  );

  const DetectionEngineMode(this.code, this.displayName);
  final String code;
  final String displayName;

  bool get includesPoseHead => this == DetectionEngineMode.yoloV8PosePosture;

  bool get includesClothHead =>
      this == DetectionEngineMode.yoloV8PosePosture ||
      this == DetectionEngineMode.yoloV8Cloth ||
      this == DetectionEngineMode.yoloV8GymClothMulti;

  bool get includesGymHead =>
      this == DetectionEngineMode.yoloV8PosePosture ||
      this == DetectionEngineMode.yoloV8Gym ||
      this == DetectionEngineMode.yoloV8GymClothMulti ||
      this == DetectionEngineMode.yoloHybrid;

  static DetectionEngineMode fromCode(String? raw) {
    for (final mode in DetectionEngineMode.values) {
      if (mode.code == raw) return mode;
    }
    return DetectionEngineMode.yoloV8PosePosture;
  }
}

/// Target gym exercise for real-time YOLOv8n-Pose biomechanical posture verification.
enum PostureExerciseTarget {
  squat(
    'squat',
    'Squat',
    '深蹲',
    'Knee Depth & Spine Alignment',
    '膝關節深度與脊柱中立',
  ),
  bicepCurl(
    'bicep_curl',
    'Bicep Curl',
    '二頭彎舉',
    'Elbow Lock & Anti-Swing',
    '手肘穩定與防借力擺動',
  ),
  shoulderPress(
    'shoulder_press',
    'Shoulder Press',
    '過頭肩推',
    'Overhead Symmetry & Core Brace',
    '雙臂對稱與核心收緊',
  ),
  deadliftPlank(
    'deadlift',
    'Deadlift / Hinge',
    '硬舉 / 髖鉸鏈',
    'Neutral Lower Back & Hip Hinge',
    '下背平直與髖部鉸鏈角度',
  );

  const PostureExerciseTarget(
    this.code,
    this.labelEn,
    this.labelZh,
    this.focusEn,
    this.focusZh,
  );

  final String code;
  final String labelEn;
  final String labelZh;
  final String focusEn;
  final String focusZh;
}

/// Real-time posture correctness classification.
enum PostureStatus {
  correct,
  needsAdjustment,
  incorrect,
}

/// Single anatomical keypoint from YOLOv8n-Pose (COCO 17-keypoint topology, normalized 0..1).
class PostureKeypoint {
  const PostureKeypoint({
    required this.index,
    required this.name,
    required this.x,
    required this.y,
    this.confidence = 0.94,
    this.isAligned = true,
  });

  final int index;
  final String name;
  final double x;
  final double y;
  final double confidence;
  final bool isAligned;
}

/// Complete real-time posture assessment computed by YOLOv8n-Pose biomechanical head.
class PostureEvaluation {
  const PostureEvaluation({
    required this.exercise,
    required this.status,
    required this.formScore,
    required this.primaryJointLabel,
    required this.primaryAngleDeg,
    required this.secondaryJointLabel,
    required this.secondaryAngleDeg,
    required this.symmetryPercent,
    required this.goodReps,
    required this.formAlerts,
    required this.headlineEn,
    required this.headlineZh,
    required this.tipEn,
    required this.tipZh,
    required this.keypoints,
    required this.modelName,
  });

  final PostureExerciseTarget exercise;
  final PostureStatus status;
  final int formScore;
  final String primaryJointLabel;
  final int primaryAngleDeg;
  final String secondaryJointLabel;
  final int secondaryAngleDeg;
  final int symmetryPercent;
  final int goodReps;
  final int formAlerts;
  final String headlineEn;
  final String headlineZh;
  final String tipEn;
  final String tipZh;
  final List<PostureKeypoint> keypoints;
  final String modelName;

  bool get isCorrect => status == PostureStatus.correct;
}

/// Model for `public.camera_detections` storing YOLO / ML Kit object, cloth & posture metadata.
class CameraDetectionRecord {
  const CameraDetectionRecord({
    required this.id,
    required this.userId,
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.detectedAt,
    this.detectionEngine = 'yolov8n_pose',
    this.classId = 0,
    this.inferenceMs = 12.8,
    this.suggestedExercise,
    this.imagePath,
    this.isSavedToCloud = false,
  });

  final String id;
  final String userId;
  final String label;
  final double confidence;
  final Rect boundingBox;
  final int sourceWidth;
  final int sourceHeight;
  final DateTime detectedAt;
  final String detectionEngine;
  final int classId;
  final double inferenceMs;
  final String? suggestedExercise;
  final String? imagePath;
  final bool isSavedToCloud;

  /// True when this detection belongs to the YOLOv8-Cloth apparel/gear catalog (`classId >= 10 && classId < 20`).
  bool get isClothCategory =>
      (classId >= 10 && classId < 20) ||
      detectionEngine == 'yolov8_cloth' ||
      label.toLowerCase().contains('cloth:');

  /// True when this detection represents a YOLOv8n-Pose posture evaluation (`classId >= 20`).
  bool get isPostureCategory =>
      classId >= 20 || label.toLowerCase().contains('posture:');

  /// Concise, humanized display title without noisy prefixes.
  String get conciseTitle {
    return label
        .replaceAll('YOLO-Pose: ', '')
        .replaceAll('YOLO-Cloth: ', '')
        .replaceAll('YOLO: ', '')
        .replaceAll('cloth: ', '')
        .replaceAll('posture: ', '')
        .replaceAll('_', ' ');
  }

  factory CameraDetectionRecord.fromJson(Map<String, dynamic> json) {
    final rawBox = json['bounding_box'];
    Rect box = Rect.zero;
    if (rawBox is Map) {
      final left =
          (rawBox['left'] is num) ? (rawBox['left'] as num).toDouble() : 0.0;
      final top =
          (rawBox['top'] is num) ? (rawBox['top'] as num).toDouble() : 0.0;
      final right =
          (rawBox['right'] is num) ? (rawBox['right'] as num).toDouble() : 0.0;
      final bottom = (rawBox['bottom'] is num)
          ? (rawBox['bottom'] as num).toDouble()
          : 0.0;
      box = Rect.fromLTRB(left, top, right, bottom);
    }

    return CameraDetectionRecord(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      label: (json['label'] ?? 'Detected Object').toString(),
      confidence: json['confidence'] is num
          ? (json['confidence'] as num).toDouble()
          : 0.0,
      boundingBox: box,
      sourceWidth: json['source_width'] is num
          ? (json['source_width'] as num).toInt()
          : 0,
      sourceHeight: json['source_height'] is num
          ? (json['source_height'] as num).toInt()
          : 0,
      detectedAt: json['detected_at'] != null
          ? (DateTime.tryParse(json['detected_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      detectionEngine:
          (json['detection_engine'] ?? 'yolov8n_pose').toString(),
      classId: json['class_id'] is num ? (json['class_id'] as num).toInt() : 0,
      inferenceMs: json['inference_ms'] is num
          ? (json['inference_ms'] as num).toDouble()
          : 12.8,
      suggestedExercise: json['suggested_exercise']?.toString(),
      imagePath: json['image_path']?.toString(),
      isSavedToCloud: json['is_saved_to_cloud'] == true,
    );
  }

  Map<String, dynamic> toDatabaseRow() {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'confidence': double.parse(confidence.toStringAsFixed(4)),
      'bounding_box': {
        'left': boundingBox.left,
        'top': boundingBox.top,
        'right': boundingBox.right,
        'bottom': boundingBox.bottom,
      },
      'source_width': sourceWidth,
      'source_height': sourceHeight,
      'detected_at': detectedAt.toUtc().toIso8601String(),
      'detection_engine': detectionEngine,
      'class_id': classId,
      'inference_ms': double.parse(inferenceMs.toStringAsFixed(2)),
      'suggested_exercise': suggestedExercise,
      'image_path': imagePath,
    };
  }

  CameraDetectionRecord copyWith({
    bool? isSavedToCloud,
    String? imagePath,
    String? detectionEngine,
    int? classId,
    double? inferenceMs,
    String? suggestedExercise,
  }) {
    return CameraDetectionRecord(
      id: id,
      userId: userId,
      label: label,
      confidence: confidence,
      boundingBox: boundingBox,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      detectedAt: detectedAt,
      detectionEngine: detectionEngine ?? this.detectionEngine,
      classId: classId ?? this.classId,
      inferenceMs: inferenceMs ?? this.inferenceMs,
      suggestedExercise: suggestedExercise ?? this.suggestedExercise,
      imagePath: imagePath ?? this.imagePath,
      isSavedToCloud: isSavedToCloud ?? this.isSavedToCloud,
    );
  }
}


/// Explicit 10-state camera & on-device AI model lifecycle machine (Mandatory Task 8).
enum CameraLifecycleStage {
  permissionNotRequested('Permission not requested', '尚未請求相機權限'),
  permissionDenied('Permission denied', '相機權限被拒絕'),
  permissionPermanentlyDenied(
    'Permission permanently denied (Open Settings)',
    '相機權限已永久拒絕（請開啟系統設定）',
  ),
  cameraInitializing('Camera initializing...', '正在初始化相機...'),
  cameraReady('Camera ready', '相機已就緒'),
  modelLoading('Model loading...', '正在載入 YOLO 模型...'),
  modelReady('Model ready', 'YOLO 模型已就緒'),
  detectionActive('Detection active (Real-Time)', '即時姿勢與物件偵測運行中'),
  paused('Detection paused', '即時偵測已暫停'),
  errorWithRetry('Camera/Model error (Tap Retry)', '相機或模型發生錯誤（請點擊重試）');

  const CameraLifecycleStage(this.labelEn, this.labelZh);
  final String labelEn;
  final String labelZh;

  String localizedLabel(bool isZh) => isZh ? labelZh : labelEn;
}

/// Resolution and frame-throttling performance presets for on-device inference.
enum CameraPerformancePreset {
  lowPower360p('Low Power (360p • 650ms)', '省電模式 (360p • 650ms)', '640x360', 650),
  balanced720p('Balanced (720p • 400ms)', '平衡模式 (720p • 400ms)', '1280x720', 400),
  highAccuracy1080p('High Precision (1080p • 260ms)', '高精度模式 (1080p • 260ms)', '1920x1080', 260);

  const CameraPerformancePreset(
    this.labelEn,
    this.labelZh,
    this.resolutionLabel,
    this.intervalMs,
  );

  final String labelEn;
  final String labelZh;
  final String resolutionLabel;
  final int intervalMs;

  String localizedLabel(bool isZh) => isZh ? labelZh : labelEn;
}

/// Immutable snapshot of a single real-time camera detection frame showcased
/// live in the Camera screen and Dashboard.
class RealTimeShowcaseFrame {
  const RealTimeShowcaseFrame({
    required this.frameNumber,
    required this.timestampUtc,
    required this.posture,
    required this.detections,
    required this.inferenceMs,
    required this.estimatedFps,
    required this.inputResolution,
    required this.delegateMode,
    required this.summaryEn,
    required this.summaryZh,
  });

  final int frameNumber;
  final DateTime timestampUtc;
  final PostureEvaluation posture;
  final List<CameraDetectionRecord> detections;
  final double inferenceMs;
  final double estimatedFps;
  final String inputResolution;
  final String delegateMode;
  final String summaryEn;
  final String summaryZh;

  String localizedSummary(bool isZh) => isZh ? summaryZh : summaryEn;
}
