import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/theme/glass_theme.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';

/// Wraps a screen body in the Glass Theme gradient background.
class GlassScaffoldBackground extends StatelessWidget {
  const GlassScaffoldBackground({
    super.key,
    required this.glassEnabled,
    required this.child,
  });

  final bool glassEnabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: GlassTheme.gradientBackground(
        brightness: brightness,
        glassEnabled: glassEnabled,
      ),
      child: child,
    );
  }
}

/// Selective Glassmorphism surface using BackdropFilter when glassEnabled is true.
/// Never wrap the live CameraPreview inside a BackdropFilter.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.glassEnabled,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.borderRadius = 22,
  });

  final bool glassEnabled;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final surfaceColor = glassEnabled
        ? (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.72))
        : (isDark ? const Color(0xFF162632) : Colors.white);
    final borderColor = glassEnabled
        ? Colors.white.withValues(alpha: isDark ? 0.16 : 0.68)
        : (isDark
              ? Colors.white.withValues(alpha: 0.10)
              : const Color(0xFFD5E3D8));

    final panelBody = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );

    if (!glassEnabled) {
      return Padding(padding: margin, child: panelBody);
    }

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: panelBody,
        ),
      ),
    );
  }
}

/// Accessible section header with icon and optional trailing widget.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Semantics(
            label: title,
            child: Icon(icon, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Standardized empty state card with optional action button.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: scheme.primary.withValues(alpha: 0.8)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standardized error state banner with retry button.
class ErrorBannerCard extends StatelessWidget {
  const ErrorBannerCard({
    super.key,
    required this.message,
    this.retryLabel = 'Retry',
    this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.error.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}

/// Responsive line chart for strength/weight trends without misleading extrapolation.
class SimpleTrendChart extends StatelessWidget {
  const SimpleTrendChart({
    super.key,
    required this.values,
    required this.labels,
    required this.unit,
    required this.emptyText,
  });

  final List<double> values;
  final List<String> labels;
  final String unit;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(emptyText, style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrendLinePainter(
          values: values,
          lineColor: GlassTheme.limeAccent,
          gridColor: scheme.outlineVariant.withValues(alpha: 0.35),
          textColor: scheme.onSurface,
          unit: unit,
          labels: labels,
        ),
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  _TrendLinePainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.unit,
    required this.labels,
  });

  final List<double> values;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final String unit;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 12.0;
    const rightPad = 12.0;
    const topPad = 20.0;
    const bottomPad = 26.0;
    final chartW = (size.width - leftPad - rightPad).clamp(10.0, size.width);
    final chartH = (size.height - topPad - bottomPad).clamp(10.0, size.height);

    double minV = values.first;
    double maxV = values.first;
    for (final v in values) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final span = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 2; i++) {
      final y = topPad + (chartH * i / 2);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + chartW, y),
        gridPaint,
      );
    }

    final path = Path();
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = leftPad + (chartW * i / (values.length - 1));
      final norm = (values[i] - minV) / span;
      final y = topPad + chartH - (norm * chartH);
      final pt = Offset(x, y);
      points.add(pt);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    final dotPaint = Paint()..color = lineColor;
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4.5, dotPaint);
      if (i == 0 || i == points.length - 1) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${values[i].toStringAsFixed(1)}$unit',
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = (points[i].dx - tp.width / 2).clamp(
          0.0,
          size.width - tp.width,
        );
        tp.paint(canvas, Offset(dx, 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.unit != unit;
  }
}

/// Overlay painter for YOLOv8n-Pose 17-Keypoint Human Skeleton, Joint Angle Badges,
/// and Concise Equipment / Sportswear Bounding Boxes.
class DetectionBoundingBoxOverlay extends StatelessWidget {
  const DetectionBoundingBoxOverlay({
    super.key,
    required this.detections,
    this.postureEvaluation,
    this.flipX = false,
  });

  final List<CameraDetectionRecord> detections;
  final PostureEvaluation? postureEvaluation;
  final bool flipX;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BoundingBoxPainter(
          detections: detections,
          posture: postureEvaluation,
          flipX: flipX,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  _BoundingBoxPainter({
    required this.detections,
    this.posture,
    required this.flipX,
  });

  final List<CameraDetectionRecord> detections;
  final PostureEvaluation? posture;
  final bool flipX;

  static const Color _clothCyan = Color(0xFF64D2FF);
  static const Color _poseGreen = Color(0xFF30D158);
  static const Color _poseAmber = Color(0xFFFF9F0A);
  static const Color _poseRed = Color(0xFFFF453A);

  static const List<List<int>> _skeletonEdges = <List<int>>[
    <int>[0, 1],
    <int>[0, 2],
    <int>[1, 3],
    <int>[2, 4],
    <int>[5, 6],
    <int>[5, 7],
    <int>[7, 9],
    <int>[6, 8],
    <int>[8, 10],
    <int>[5, 11],
    <int>[6, 12],
    <int>[11, 12],
    <int>[11, 13],
    <int>[13, 15],
    <int>[12, 14],
    <int>[14, 16],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw subtle, concise bounding boxes for detected gym equipment & apparel
    for (final det in detections) {
      if (det.isPostureCategory) continue;
      final isCloth = det.isClothCategory;
      final accent = isCloth ? _clothCyan : GlassTheme.limeAccent;

      final boxPaint = Paint()
        ..color = accent.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;

      final fillPaint = Paint()
        ..color = accent.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;

      final srcW = det.sourceWidth <= 0
          ? size.width
          : det.sourceWidth.toDouble();
      final srcH = det.sourceHeight <= 0
          ? size.height
          : det.sourceHeight.toDouble();
      final scale = math.max(size.width / srcW, size.height / srcH);
      final offsetX = (size.width - srcW * scale) / 2;
      final offsetY = (size.height - srcH * scale) / 2;
      final rawLeft = offsetX + det.boundingBox.left * scale;
      final rawRight = offsetX + det.boundingBox.right * scale;
      final left = flipX ? size.width - rawRight : rawLeft;
      final right = flipX ? size.width - rawLeft : rawRight;

      final rect = Rect.fromLTRB(
        left.clamp(0.0, size.width),
        (offsetY + det.boundingBox.top * scale).clamp(0.0, size.height),
        right.clamp(0.0, size.width),
        (offsetY + det.boundingBox.bottom * scale).clamp(0.0, size.height),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        boxPaint,
      );

      final labelSpan = TextSpan(
        text:
            ' ${det.conciseTitle} ${(det.confidence * 100).toStringAsFixed(0)}% ',
        style: TextStyle(
          color: const Color(0xFF050A0E),
          backgroundColor: accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      );
      final tp = TextPainter(text: labelSpan, textDirection: TextDirection.ltr)
        ..layout(maxWidth: size.width);
      final labelY = (rect.top - tp.height - 2).clamp(
        0.0,
        size.height - tp.height,
      );
      final labelX = rect.left.clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(labelX, labelY));
    }

    // 2. Draw Real-Time YOLOv8n-Pose 17-Keypoint Human Skeleton & Joint Angle HUD
    final p = posture;
    if (p == null || p.keypoints.isEmpty) return;

    final statusColor = switch (p.status) {
      PostureStatus.correct => _poseGreen,
      PostureStatus.needsAdjustment => _poseAmber,
      PostureStatus.incorrect => _poseRed,
    };

    final kpMap = <int, Offset>{};
    final kpValid = <int, bool>{};
    for (final kp in p.keypoints) {
      kpMap[kp.index] = Offset(
        (kp.x * size.width).clamp(8.0, size.width - 8.0),
        (kp.y * size.height).clamp(8.0, size.height - 8.0),
      );
      kpValid[kp.index] = kp.isAligned;
    }

    final boneGlowPaint = Paint()
      ..color = statusColor.withValues(alpha: 0.28)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round;

    final boneCorePaint = Paint()
      ..color = statusColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    for (final edge in _skeletonEdges) {
      final a = kpMap[edge[0]];
      final b = kpMap[edge[1]];
      if (a != null && b != null) {
        final edgeAligned =
            (kpValid[edge[0]] ?? true) && (kpValid[edge[1]] ?? true);
        boneCorePaint.color = edgeAligned ? statusColor : _poseAmber;
        canvas.drawLine(a, b, boneGlowPaint);
        canvas.drawLine(a, b, boneCorePaint);
      }
    }

    final jointOuterPaint = Paint()..color = Colors.white;
    final jointInnerPaint = Paint()..color = statusColor;

    for (final kp in p.keypoints) {
      final pt = kpMap[kp.index];
      if (pt == null) continue;
      jointInnerPaint.color = kp.isAligned ? statusColor : _poseRed;
      canvas.drawCircle(pt, 5.2, jointOuterPaint);
      canvas.drawCircle(pt, 3.6, jointInnerPaint);
    }

    // 3. Draw SVG-style Joint Angle Protractor Arcs (Elbow 5-7-9, Hip 5-11-13, Knee 11-13-15)
    final shPt = kpMap[5];
    final elbPt = kpMap[7];
    final wrPt = kpMap[9];
    final hipPt = kpMap[11] ?? Offset(size.width * 0.46, size.height * 0.54);
    final kneePt = kpMap[13] ?? Offset(size.width * 0.44, size.height * 0.72);
    final ankPt = kpMap[15];

    if (shPt != null && elbPt != null && wrPt != null) {
      _drawJointAngleArc(
        canvas,
        elbPt,
        shPt,
        wrPt,
        16.0,
        const Color(0xFFFDE047),
      );
    }
    if (shPt != null && ankPt != null) {
      _drawJointAngleArc(canvas, hipPt, shPt, kneePt, 18.0, statusColor);
    }

    final primaryAnchor = p.exercise == PostureExerciseTarget.pushUp
        ? (elbPt ?? kneePt)
        : kneePt;
    _drawAnglePill(
      canvas,
      size,
      anchor: Offset(primaryAnchor.dx + 10, primaryAnchor.dy - 14),
      text: '${p.primaryJointLabel} ${p.primaryAngleDeg}°',
      color: const Color(0xFFFDE047),
    );
    _drawAnglePill(
      canvas,
      size,
      anchor: Offset(hipPt.dx - 16, hipPt.dy - 24),
      text: '${p.secondaryJointLabel} ${p.secondaryAngleDeg}°',
      color: statusColor,
    );

    // 4. Right-Side Vertical ROM / Depth Gauge Bar (0% - 100%, pushup_unseen.mp4 CV style)
    final barRight = size.width - 14.0;
    final barTop = size.height * 0.18;
    final barHeight = size.height * 0.58;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barRight - 12, barTop, 12, barHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(trackRect, Paint()..color = const Color(0xCC0B1322));
    canvas.drawRRect(
      trackRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final romNorm = (p.romPercent / 100.0).clamp(0.04, 1.0);
    final fillH = barHeight * romNorm;
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barRight - 10, barTop + (barHeight - fillH), 8, fillH),
      const Radius.circular(4),
    );
    canvas.drawRRect(fillRect, Paint()..color = statusColor);
    _drawAnglePill(
      canvas,
      size,
      anchor: Offset(barRight - 46, barTop + barHeight + 4),
      text: 'ROM ${p.romPercent}%',
      color: statusColor,
    );

    // 5. Top-Left REPS & STAGE (DOWN / UP) CV Counter Box
    _drawAnglePill(
      canvas,
      size,
      anchor: const Offset(12, 42),
      text:
          'REPS ${p.goodReps} • STAGE: ${p.repStage} ${p.repStage == "DOWN" ? "▼" : "▲"}',
      color: statusColor,
    );
  }

  void _drawJointAngleArc(
    Canvas canvas,
    Offset vertex,
    Offset p1,
    Offset p2,
    double radius,
    Color color,
  ) {
    final a1 = math.atan2(p1.dy - vertex.dy, p1.dx - vertex.dx);
    final a2 = math.atan2(p2.dy - vertex.dy, p2.dx - vertex.dx);
    double sweep = a2 - a1;
    while (sweep < -math.pi) {
      sweep += math.pi * 2;
    }
    while (sweep > math.pi) {
      sweep -= math.pi * 2;
    }
    final rect = Rect.fromCircle(center: vertex, radius: radius);
    canvas.drawArc(
      rect,
      a1,
      sweep,
      true,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawArc(
      rect,
      a1,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  void _drawAnglePill(
    Canvas canvas,
    Size size, {
    required Offset anchor,
    required String text,
    required Color color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: ' $text ',
        style: TextStyle(
          color: Colors.white,
          backgroundColor: const Color(0xD9081018),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final dx = anchor.dx.clamp(4.0, size.width - tp.width - 4.0);
    final dy = anchor.dy.clamp(4.0, size.height - tp.height - 4.0);
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.posture != posture ||
        oldDelegate.flipX != flipX;
  }
}

/// Accessible status pill combining icon, text, and high-contrast border so
/// status is never communicated by color alone (Task 12 Accessibility).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeuomorphic Stitched Leather Notebook container for the Digital Calendar (#9)
/// and Bento Studio (`@design-system`, `@ui-ux-pro-max`).
class SkeuomorphicLeatherNotebook extends StatelessWidget {
  const SkeuomorphicLeatherNotebook({
    super.key,
    required this.child,
    this.title = 'STITCHED LEATHER LOGBOOK • MARCH 2026',
  });

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5C3820), Color(0xFF3D2312)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A160A), width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Metallic Spiral Binder Rings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              7,
              (_) => Container(
                width: 10,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF94A3B8),
                      Color(0xFFF8FAFC),
                      Color(0xFF475569),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.65),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFDE68A),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF9F0),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFFDFD3BC), offset: Offset(0, 3)),
                    ],
                  ),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Color(0xFF2C1D11)),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
