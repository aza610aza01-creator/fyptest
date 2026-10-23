import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/theme/glass_theme.dart';
import 'package:ai_gym_flutter/services/notification_service.dart';

/// Displays an interactive Rest Timer bar with +/- 15s controls and completion alerts.
class RestTimerBanner extends StatelessWidget {
  const RestTimerBanner({
    super.key,
    this.notifications,
    this.notificationService,
    this.glassEnabled = true,
    required this.isZh,
  }) : assert(
         notifications != null || notificationService != null,
         'Either notifications or notificationService must be provided.',
       );

  final NotificationService? notifications;
  final NotificationService? notificationService;
  final bool glassEnabled;
  final bool isZh;

  NotificationService get _activeNotifications =>
      notifications ?? notificationService!;

  @override
  Widget build(BuildContext context) {
    final active = _activeNotifications;
    return ListenableBuilder(
      listenable: active,
      builder: (context, _) {
        final running = active.isRunning;
        final bannerMsg = active.activeBannerMessage;
        if (!running && bannerMsg == null) {
          return const SizedBox.shrink();
        }

        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: glassEnabled ? 0.90 : 0.98),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GlassTheme.limeAccent, width: 1.4),
            ),
            child: running
                ? Row(
                    children: [
                      const Icon(Icons.timer, color: GlassTheme.limeAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isZh
                                  ? '組間休息計時：${active.formattedRemaining}'
                                  : 'Rest Timer: ${active.formattedRemaining}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: active.progress,
                              backgroundColor:
                                  scheme.outlineVariant.withValues(alpha: 0.3),
                              color: GlassTheme.limeAccent,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '-15s',
                        onPressed: () => active.adjustRestSeconds(-15),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      IconButton(
                        tooltip: '+15s',
                        onPressed: () => active.adjustRestSeconds(15),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      IconButton(
                        tooltip: isZh ? '停止計時' : 'Stop Timer',
                        onPressed: active.stopRestTimer,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: GlassTheme.limeAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bannerMsg ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        onPressed: active.dismissBanner,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
