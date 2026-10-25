import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/controllers/navigation_controller.dart';
import 'package:ai_gym_flutter/controllers/sync_controller.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/services/camera_detection_service.dart';
import 'package:ai_gym_flutter/services/notification_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';
import 'package:ai_gym_flutter/widgets/rest_timer_banner.dart';

/// Responsive application shell supporting:
/// - `< 600px`: 5-Tab Bottom NavigationBar (`Home`, `Workout`, `Progress`, `Camera`, `More`)
/// - `600px–1024px`: Compact `NavigationRail`
/// - `> 1024px`: Extended `NavigationRail` with centered max-width content container
/// Also gates simulated iOS 18 Dynamic Island preview behind Developer Mode / Admin.
class ResponsiveAppShell extends StatelessWidget {
  const ResponsiveAppShell({
    super.key,
    required this.user,
    required this.prefs,
    required this.navigationController,
    required this.syncController,
    required this.cameraService,
    required this.notifications,
    required this.pages,
    required this.onSyncNow,
  });

  final AppUser user;
  final PreferenceService prefs;
  final NavigationController navigationController;
  final SyncController syncController;
  final CameraDetectionService cameraService;
  final NotificationService notifications;
  final List<Widget> pages;
  final VoidCallback onSyncNow;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, prefs.languageCode);
    final isZh = strings.isZh;
    final glass = prefs.glassThemeEnabled;
    final showIosPreviewChrome =
        (prefs.developerModeEnabled || user.isAdmin) &&
            prefs.iosPreviewModeEnabled;

    return ListenableBuilder(
      listenable: navigationController,
      builder: (context, _) {
        final selectedIndex = navigationController.selectedIndex;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isDesktop = width >= 1024;
            final isTablet = width >= 600 && width < 1024;

            return Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(showIosPreviewChrome ? 92 : 58),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showIosPreviewChrome)
                      _DeveloperPreviewStatusBar(
                        cameraService: cameraService,
                        notifications: notifications,
                        isZh: isZh,
                        onTapCamera: () => navigationController.selectTab(3),
                      ),
                    AppBar(
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF30D158), Color(0xFF0A84FF)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'POSE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF04080C),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              strings.tr('app_title'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        // Localized Sync Pill (listens only to syncController)
                        ListenableBuilder(
                          listenable: syncController,
                          builder: (context, _) {
                            final pending = syncController.pendingCount;
                            final syncing = syncController.isSyncing;
                            return IconButton(
                              tooltip: isZh
                                  ? '雲端同步狀態 (待同步: $pending)'
                                  : 'Cloud Sync Status ($pending pending)',
                              onPressed: onSyncNow,
                              icon: Badge(
                                isLabelVisible: pending > 0,
                                label: Text('$pending'),
                                child: Icon(
                                  syncing
                                      ? Icons.sync
                                      : (syncController.isOnline
                                          ? Icons.cloud_done_outlined
                                          : Icons.cloud_off_outlined),
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
                        // Localized Rest Timer Pill (listens only to notifications)
                        ListenableBuilder(
                          listenable: notifications,
                          builder: (context, _) {
                            if (!notifications.isRunning) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                avatar: const Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: Color(0xFF30D158),
                                ),
                                label: Text(
                                  notifications.formattedRemaining,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                onPressed: () =>
                                    navigationController.selectTab(1),
                              ),
                            );
                          },
                        ),
                        // Single Quick Settings Sheet Button (decluttered AppBar)
                        IconButton(
                          key: const Key('appbar_quick_settings_button'),
                          tooltip: isZh ? '快速外觀與語言設定' : 'Quick Display & Language',
                          icon: const Icon(Icons.tune_rounded, size: 20),
                          onPressed: () => _showQuickDisplaySheet(context, isZh),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              body: Stack(
                children: [
                  Row(
                    children: [
                      if (isTablet || isDesktop)
                        NavigationRail(
                          extended: isDesktop,
                          selectedIndex: selectedIndex,
                          onDestinationSelected: navigationController.selectTab,
                          leading: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Icon(
                              user.isGuest
                                  ? Icons.person_outline
                                  : Icons.verified_user_outlined,
                              color: const Color(0xFF30D158),
                            ),
                          ),
                          destinations: [
                            NavigationRailDestination(
                              icon: const Icon(Icons.dashboard_outlined),
                              selectedIcon: const Icon(Icons.dashboard),
                              label: Text(strings.tr('nav_dashboard')),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.fitness_center_outlined),
                              selectedIcon: const Icon(Icons.fitness_center),
                              label: Text(strings.tr('nav_workout')),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.insights_outlined),
                              selectedIcon: const Icon(Icons.insights),
                              label: Text(strings.tr('nav_progress')),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.videocam_outlined),
                              selectedIcon: const Icon(Icons.videocam),
                              label: Text(strings.tr('nav_camera')),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.grid_view_outlined),
                              selectedIcon: const Icon(Icons.grid_view_rounded),
                              label: Text(isZh ? '更多功能' : 'More'),
                            ),
                          ],
                        ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isDesktop ? 1240 : double.infinity,
                            ),
                            child: IndexedStack(
                              index: selectedIndex,
                              children: pages,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: RestTimerBanner(
                      notificationService: notifications,
                      glassEnabled: glass,
                      isZh: isZh,
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: (isTablet || isDesktop)
                  ? null
                  : NavigationBar(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: navigationController.selectTab,
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.dashboard_outlined),
                          selectedIcon: const Icon(Icons.dashboard),
                          label: strings.tr('nav_dashboard'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.fitness_center_outlined),
                          selectedIcon: const Icon(Icons.fitness_center),
                          label: strings.tr('nav_workout'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.insights_outlined),
                          selectedIcon: const Icon(Icons.insights),
                          label: strings.tr('nav_progress'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.videocam_outlined),
                          selectedIcon: const Icon(Icons.videocam),
                          label: strings.tr('nav_camera'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.grid_view_outlined),
                          selectedIcon: const Icon(Icons.grid_view_rounded),
                          label: isZh ? '更多' : 'More',
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  void _showQuickDisplaySheet(BuildContext context, bool isZh) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: prefs,
          builder: (context, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isZh ? '快速顯示與語言設定' : 'Quick Display & Language',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(isZh ? '繁體中文介面 (HK)' : 'Traditional Chinese (繁體中文)'),
                      value: prefs.languageCode == 'zh',
                      onChanged: (v) => prefs.setLanguageCode(v ? 'zh' : 'en'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(isZh ? 'iOS 液態玻璃主題' : 'Liquid Glass Theme'),
                      value: prefs.glassThemeEnabled,
                      onChanged: prefs.setGlassThemeEnabled,
                    ),
                    if (prefs.developerModeEnabled || user.isAdmin)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          isZh
                              ? '開發者 iOS 動態島預覽邊框'
                              : 'Developer iOS Dynamic Island Preview Chrome',
                        ),
                        value: prefs.iosPreviewModeEnabled,
                        onChanged: prefs.setIosPreviewModeEnabled,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DeveloperPreviewStatusBar extends StatelessWidget {
  const _DeveloperPreviewStatusBar({
    required this.cameraService,
    required this.notifications,
    required this.isZh,
    required this.onTapCamera,
  });

  final CameraDetectionService cameraService;
  final NotificationService notifications;
  final bool isZh;
  final VoidCallback onTapCamera;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([cameraService, notifications]),
      builder: (context, _) {
        final toolbarText = notifications.isRunning
            ? '${notifications.formattedRemaining} • ${cameraService.formatToolbarStatus(isZh: isZh)}'
            : cameraService.formatToolbarStatus(isZh: isZh);

        return Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: const Color(0xFF070A0F),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PREVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64D2FF),
                ),
              ),
              InkWell(
                onTap: onTapCamera,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sensors,
                        size: 12,
                        color: Color(0xFF30D158),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        toolbarText,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(
                Icons.developer_mode,
                size: 14,
                color: Color(0xFF98989F),
              ),
            ],
          ),
        );
      },
    );
  }
}
