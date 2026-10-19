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
        ? Colors.white.withValues(alpha: isDark ? 0.20 : 0.68)
        : (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : const Color(0xFFD5E3D8));

    final panelBody = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1.15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (!glassEnabled) {
      return Padding(
        padding: margin,
        child: panelBody,
      );
    }

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Semantics(
            label: title,
            child: Icon(icon, color: scheme.primary, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
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
            Icon(icon, size: 44, color: scheme.primary.withValues(alpha: 0.8)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
              TextButton(
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
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
        child: Text(
          emptyText,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
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
        final dx = (points[i].dx - tp.width / 2)
            .clamp(0.0, size.width - tp.width);
        tp.paint(canvas, Offset(dx, 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.unit != unit;
  }
}

/// Scaled bounding-box overlay painter for ML Kit camera detections.
class DetectionBoundingBoxOverlay extends StatelessWidget {
  const DetectionBoundingBoxOverlay({
    super.key,
    required this.detections,
  });

  final List<CameraDetectionRecord> detections;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BoundingBoxPainter(detections: detections),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  _BoundingBoxPainter({required this.detections});

  final List<CameraDetectionRecord> detections;

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    final boxPaint = Paint()
      ..color = GlassTheme.limeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..color = GlassTheme.limeAccent.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    for (final det in detections) {
      final srcW = det.sourceWidth <= 0 ? size.width : det.sourceWidth.toDouble();
      final srcH = det.sourceHeight <= 0 ? size.height : det.sourceHeight.toDouble();
      final scaleX = size.width / srcW;
      final scaleY = size.height / srcH;

      final rect = Rect.fromLTRB(
        (det.boundingBox.left * scaleX).clamp(0.0, size.width),
        (det.boundingBox.top * scaleY).clamp(0.0, size.height),
        (det.boundingBox.right * scaleX).clamp(0.0, size.width),
        (det.boundingBox.bottom * scaleY).clamp(0.0, size.height),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        boxPaint,
      );

      final labelSpan = TextSpan(
        text: '${det.label} ${(det.confidence * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Color(0xFF0A141D),
          backgroundColor: GlassTheme.limeAccent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
      final tp = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      final labelY = (rect.top - tp.height - 4).clamp(0.0, size.height - tp.height);
      tp.paint(canvas, Offset(rect.left.clamp(0.0, size.width - tp.width), labelY));
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
