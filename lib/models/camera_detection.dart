import 'dart:ui';

/// Model for `public.camera_detections` storing ML Kit general object detection metadata.
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
  final String? imagePath;
  final bool isSavedToCloud;

  factory CameraDetectionRecord.fromJson(Map<String, dynamic> json) {
    final rawBox = json['bounding_box'];
    Rect box = Rect.zero;
    if (rawBox is Map) {
      final left = (rawBox['left'] is num) ? (rawBox['left'] as num).toDouble() : 0.0;
      final top = (rawBox['top'] is num) ? (rawBox['top'] as num).toDouble() : 0.0;
      final right =
          (rawBox['right'] is num) ? (rawBox['right'] as num).toDouble() : 0.0;
      final bottom =
          (rawBox['bottom'] is num) ? (rawBox['bottom'] as num).toDouble() : 0.0;
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
      'image_path': imagePath,
    };
  }

  CameraDetectionRecord copyWith({
    bool? isSavedToCloud,
    String? imagePath,
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
      imagePath: imagePath ?? this.imagePath,
      isSavedToCloud: isSavedToCloud ?? this.isSavedToCloud,
    );
  }
}
