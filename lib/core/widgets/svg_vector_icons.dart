import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Semantic SVG vector icon catalog for AI Gym Cloud v5.2.
/// Renders crisp, resolution-independent vector strokes & paths at any DPI
/// without requiring external binary assets or fragile third-party packages.
enum AiGymSvgIconName {
  cameraCoach,
  homeDashboard,
  workoutDumbbell,
  progressChart,
  moreGrid,
  shieldOtp,
  mailCode,
  smtpServer,
  poseSkeleton,
  flameCalories,
  heartPulse,
  timerStopwatch,
  cloudSync,
  sunLight,
  moonDark,
  checkVerified,
  warningAlert,
  sparklesAi,
  domainGlobe,
  keyToken,
}

class AiGymSvgIcon extends StatelessWidget {
  final AiGymSvgIconName name;
  final double size;
  final Color? color;
  final double strokeWidth;
  final String? semanticLabel;

  const AiGymSvgIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 2.0,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: semanticLabel ?? name.name,
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AiGymSvgIconPainter(
            name: name,
            color: effectiveColor,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _AiGymSvgIconPainter extends CustomPainter {
  final AiGymSvgIconName name;
  final Color color;
  final double strokeWidth;

  const _AiGymSvgIconPainter({
    required this.name,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;

    switch (name) {
      case AiGymSvgIconName.cameraCoach:
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(2 * s, 6 * s, 20 * s, 14 * s),
          Radius.circular(3.5 * s),
        );
        canvas.drawRRect(rrect, fill);
        canvas.drawRRect(rrect, stroke);
        final topPath = Path()
          ..moveTo(7.5 * s, 6 * s)
          ..lineTo(9.2 * s, 3.5 * s)
          ..lineTo(14.8 * s, 3.5 * s)
          ..lineTo(16.5 * s, 6 * s);
        canvas.drawPath(topPath, stroke);
        canvas.drawCircle(Offset(12 * s, 13 * s), 3.6 * s, stroke);
        canvas.drawCircle(Offset(17.8 * s, 9.2 * s), 0.9 * s, Paint()..color = color);
        break;

      case AiGymSvgIconName.homeDashboard:
        final roof = Path()
          ..moveTo(3 * s, 10.2 * s)
          ..lineTo(12 * s, 3 * s)
          ..lineTo(21 * s, 10.2 * s)
          ..lineTo(21 * s, 20 * s)
          ..lineTo(3 * s, 20 * s)
          ..close();
        canvas.drawPath(roof, fill);
        canvas.drawPath(roof, stroke);
        final door = Path()
          ..moveTo(9.5 * s, 20 * s)
          ..lineTo(9.5 * s, 13.5 * s)
          ..lineTo(14.5 * s, 13.5 * s)
          ..lineTo(14.5 * s, 20 * s);
        canvas.drawPath(door, stroke);
        break;

      case AiGymSvgIconName.workoutDumbbell:
        canvas.drawLine(Offset(6.5 * s, 12 * s), Offset(17.5 * s, 12 * s), stroke);
        for (final x in [4.2, 6.5, 17.5, 19.8]) {
          final isOuter = x == 4.2 || x == 19.8;
          final h = isOuter ? 7.0 : 11.0;
          final y = (24.0 - h) / 2.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH((x - 1.0) * s, y * s, 2.0 * s, h * s),
              Radius.circular(1 * s),
            ),
            stroke,
          );
        }
        break;

      case AiGymSvgIconName.progressChart:
        final trend = Path()
          ..moveTo(3 * s, 17 * s)
          ..lineTo(8.5 * s, 11.5 * s)
          ..lineTo(13 * s, 14.5 * s)
          ..lineTo(20.5 * s, 6.5 * s);
        canvas.drawPath(trend, stroke);
        final arrow = Path()
          ..moveTo(15.5 * s, 6.5 * s)
          ..lineTo(20.5 * s, 6.5 * s)
          ..lineTo(20.5 * s, 11.5 * s);
        canvas.drawPath(arrow, stroke);
        canvas.drawLine(Offset(3 * s, 20.5 * s), Offset(21 * s, 20.5 * s), stroke);
        break;

      case AiGymSvgIconName.moreGrid:
        for (final row in [6.5, 12.0, 17.5]) {
          for (final col in [6.5, 12.0, 17.5]) {
            canvas.drawCircle(Offset(col * s, row * s), 1.5 * s, stroke);
          }
        }
        break;

      case AiGymSvgIconName.shieldOtp:
        final shield = Path()
          ..moveTo(12 * s, 2.5 * s)
          ..lineTo(19.5 * s, 5.8 * s)
          ..lineTo(19.5 * s, 11.8 * s)
          ..quadraticBezierTo(19.5 * s, 18.2 * s, 12 * s, 21.5 * s)
          ..quadraticBezierTo(4.5 * s, 18.2 * s, 4.5 * s, 11.8 * s)
          ..lineTo(4.5 * s, 5.8 * s)
          ..close();
        canvas.drawPath(shield, fill);
        canvas.drawPath(shield, stroke);
        final check = Path()
          ..moveTo(8.8 * s, 12.2 * s)
          ..lineTo(11.1 * s, 14.5 * s)
          ..lineTo(15.5 * s, 9.5 * s);
        canvas.drawPath(check, stroke);
        break;

      case AiGymSvgIconName.mailCode:
        final env = RRect.fromRectAndRadius(
          Rect.fromLTWH(2.5 * s, 5 * s, 19 * s, 14 * s),
          Radius.circular(3 * s),
        );
        canvas.drawRRect(env, fill);
        canvas.drawRRect(env, stroke);
        final flap = Path()
          ..moveTo(3 * s, 6.2 * s)
          ..lineTo(12 * s, 12.5 * s)
          ..lineTo(21 * s, 6.2 * s);
        canvas.drawPath(flap, stroke);
        break;

      case AiGymSvgIconName.smtpServer:
        final box1 = RRect.fromRectAndRadius(
          Rect.fromLTWH(3 * s, 4 * s, 18 * s, 6.5 * s),
          Radius.circular(2 * s),
        );
        final box2 = RRect.fromRectAndRadius(
          Rect.fromLTWH(3 * s, 13.5 * s, 18 * s, 6.5 * s),
          Radius.circular(2 * s),
        );
        canvas.drawRRect(box1, fill);
        canvas.drawRRect(box1, stroke);
        canvas.drawRRect(box2, fill);
        canvas.drawRRect(box2, stroke);
        canvas.drawCircle(Offset(7 * s, 7.25 * s), 1 * s, Paint()..color = color);
        canvas.drawCircle(Offset(7 * s, 16.75 * s), 1 * s, Paint()..color = color);
        canvas.drawLine(Offset(11 * s, 7.25 * s), Offset(17.5 * s, 7.25 * s), stroke);
        canvas.drawLine(Offset(11 * s, 16.75 * s), Offset(17.5 * s, 16.75 * s), stroke);
        break;

      case AiGymSvgIconName.poseSkeleton:
        canvas.drawCircle(Offset(12 * s, 4.5 * s), 2.1 * s, stroke);
        canvas.drawLine(Offset(6 * s, 8.5 * s), Offset(18 * s, 8.5 * s), stroke);
        canvas.drawLine(Offset(12 * s, 6.8 * s), Offset(12 * s, 14.5 * s), stroke);
        canvas.drawLine(Offset(12 * s, 14.5 * s), Offset(8.5 * s, 21 * s), stroke);
        canvas.drawLine(Offset(12 * s, 14.5 * s), Offset(15.5 * s, 21 * s), stroke);
        break;

      case AiGymSvgIconName.flameCalories:
        final flame = Path()
          ..moveTo(12 * s, 2.8 * s)
          ..quadraticBezierTo(18.5 * s, 8.5 * s, 17.5 * s, 14.2 * s)
          ..quadraticBezierTo(17 * s, 20.5 * s, 12 * s, 21.2 * s)
          ..quadraticBezierTo(7 * s, 20.5 * s, 6.5 * s, 14.2 * s)
          ..quadraticBezierTo(5.8 * s, 9.2 * s, 12 * s, 2.8 * s)
          ..close();
        canvas.drawPath(flame, fill);
        canvas.drawPath(flame, stroke);
        break;

      case AiGymSvgIconName.heartPulse:
        final line = Path()
          ..moveTo(2.5 * s, 12 * s)
          ..lineTo(7 * s, 12 * s)
          ..lineTo(9.5 * s, 6.5 * s)
          ..lineTo(13.2 * s, 17.5 * s)
          ..lineTo(16 * s, 12 * s)
          ..lineTo(21.5 * s, 12 * s);
        canvas.drawPath(line, stroke);
        break;

      case AiGymSvgIconName.timerStopwatch:
        canvas.drawCircle(Offset(12 * s, 13.2 * s), 7.5 * s, fill);
        canvas.drawCircle(Offset(12 * s, 13.2 * s), 7.5 * s, stroke);
        canvas.drawLine(Offset(9.5 * s, 2.8 * s), Offset(14.5 * s, 2.8 * s), stroke);
        canvas.drawLine(Offset(12 * s, 13.2 * s), Offset(12 * s, 9.2 * s), stroke);
        canvas.drawLine(Offset(12 * s, 13.2 * s), Offset(15 * s, 15.2 * s), stroke);
        break;

      case AiGymSvgIconName.cloudSync:
        final cloud = Path()
          ..moveTo(6.5 * s, 18.5 * s)
          ..lineTo(17.5 * s, 18.5 * s)
          ..quadraticBezierTo(21 * s, 18.5 * s, 21 * s, 15 * s)
          ..quadraticBezierTo(21 * s, 11.8 * s, 18 * s, 11.5 * s)
          ..quadraticBezierTo(17.2 * s, 6.5 * s, 12.2 * s, 6.5 * s)
          ..quadraticBezierTo(7.8 * s, 6.5 * s, 6.8 * s, 10.8 * s)
          ..quadraticBezierTo(3.2 * s, 11.2 * s, 3.2 * s, 14.8 * s)
          ..quadraticBezierTo(3.2 * s, 18.5 * s, 6.5 * s, 18.5 * s);
        canvas.drawPath(cloud, fill);
        canvas.drawPath(cloud, stroke);
        break;

      case AiGymSvgIconName.sunLight:
        canvas.drawCircle(Offset(12 * s, 12 * s), 4.2 * s, fill);
        canvas.drawCircle(Offset(12 * s, 12 * s), 4.2 * s, stroke);
        for (int i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset((12 + math.cos(a) * 6.8) * s, (12 + math.sin(a) * 6.8) * s),
            Offset((12 + math.cos(a) * 9.2) * s, (12 + math.sin(a) * 9.2) * s),
            stroke,
          );
        }
        break;

      case AiGymSvgIconName.moonDark:
        final moon = Path()
          ..moveTo(15.5 * s, 3.8 * s)
          ..quadraticBezierTo(8.5 * s, 4.5 * s, 6.5 * s, 11.5 * s)
          ..quadraticBezierTo(5.2 * s, 18.2 * s, 12.8 * s, 20.2 * s)
          ..quadraticBezierTo(17.8 * s, 20.8 * s, 20.2 * s, 16.5 * s)
          ..quadraticBezierTo(12.2 * s, 16.2 * s, 12.2 * s, 9.5 * s)
          ..quadraticBezierTo(12.2 * s, 5.8 * s, 15.5 * s, 3.8 * s);
        canvas.drawPath(moon, fill);
        canvas.drawPath(moon, stroke);
        break;

      case AiGymSvgIconName.checkVerified:
        canvas.drawCircle(Offset(12 * s, 12 * s), 9 * s, fill);
        canvas.drawCircle(Offset(12 * s, 12 * s), 9 * s, stroke);
        final chk = Path()
          ..moveTo(8 * s, 12.3 * s)
          ..lineTo(10.8 * s, 15.1 * s)
          ..lineTo(16.2 * s, 9.3 * s);
        canvas.drawPath(chk, stroke);
        break;

      case AiGymSvgIconName.warningAlert:
        final tri = Path()
          ..moveTo(12 * s, 3.2 * s)
          ..lineTo(21 * s, 19.5 * s)
          ..lineTo(3 * s, 19.5 * s)
          ..close();
        canvas.drawPath(tri, fill);
        canvas.drawPath(tri, stroke);
        canvas.drawLine(Offset(12 * s, 9 * s), Offset(12 * s, 14 * s), stroke);
        canvas.drawCircle(Offset(12 * s, 17 * s), 1 * s, Paint()..color = color);
        break;

      case AiGymSvgIconName.sparklesAi:
        final star = Path()
          ..moveTo(12 * s, 3 * s)
          ..quadraticBezierTo(13 * s, 10 * s, 20 * s, 12 * s)
          ..quadraticBezierTo(13 * s, 14 * s, 12 * s, 21 * s)
          ..quadraticBezierTo(11 * s, 14 * s, 4 * s, 12 * s)
          ..quadraticBezierTo(11 * s, 10 * s, 12 * s, 3 * s)
          ..close();
        canvas.drawPath(star, fill);
        canvas.drawPath(star, stroke);
        break;

      case AiGymSvgIconName.domainGlobe:
        canvas.drawCircle(Offset(12 * s, 12 * s), 9 * s, fill);
        canvas.drawCircle(Offset(12 * s, 12 * s), 9 * s, stroke);
        canvas.drawLine(Offset(3.2 * s, 12 * s), Offset(20.8 * s, 12 * s), stroke);
        canvas.drawOval(Rect.fromLTWH(7.8 * s, 3.2 * s, 8.4 * s, 17.6 * s), stroke);
        break;

      case AiGymSvgIconName.keyToken:
        canvas.drawCircle(Offset(8 * s, 12 * s), 4.2 * s, fill);
        canvas.drawCircle(Offset(8 * s, 12 * s), 4.2 * s, stroke);
        canvas.drawLine(Offset(12.2 * s, 12 * s), Offset(21 * s, 12 * s), stroke);
        canvas.drawLine(Offset(17.5 * s, 12 * s), Offset(17.5 * s, 15.5 * s), stroke);
        canvas.drawLine(Offset(20.5 * s, 12 * s), Offset(20.5 * s, 16.5 * s), stroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _AiGymSvgIconPainter oldDelegate) {
    return oldDelegate.name != name ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Custom SVG Vector Hero Badge for 6-Digit Email OTP & Custom SMTP Security.
class AiGymSvgOtpHeroBadge extends StatelessWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final double size;

  const AiGymSvgOtpHeroBadge({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
    this.size = 76,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.25),
                  secondaryColor.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
          ),
          AiGymSvgIcon(
            AiGymSvgIconName.shieldOtp,
            size: size * 0.52,
            color: primaryColor,
            strokeWidth: 2.2,
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1018),
                shape: BoxShape.circle,
                border: Border.all(color: secondaryColor, width: 1.5),
              ),
              child: AiGymSvgIcon(
                AiGymSvgIconName.mailCode,
                size: size * 0.22,
                color: secondaryColor,
                strokeWidth: 2.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
