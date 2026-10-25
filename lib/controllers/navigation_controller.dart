import 'package:flutter/foundation.dart';

/// Primary 5-tab navigation destinations for mobile bottom navigation:
/// 0: Home, 1: Workout, 2: Progress, 3: Camera, 4: More.
enum PrimaryNavTab {
  home(0),
  workout(1),
  progress(2),
  camera(3),
  more(4);

  const PrimaryNavTab(this.tabIndex);
  final int tabIndex;

  static PrimaryNavTab fromIndex(int index) {
    for (final tab in PrimaryNavTab.values) {
      if (tab.tabIndex == index) return tab;
    }
    return PrimaryNavTab.home;
  }
}

/// Secondary sub-screens accessible inside the `More` destination (or direct
/// rail destinations on tablet/desktop).
enum MoreSubDestination {
  hub,
  exerciseLibrary,
  bodyHealth,
  settings,
  diagnostics,
}

/// Controls the 5-tab primary navigation shell and secondary `More` sub-routes.
class NavigationController extends ChangeNotifier {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  int _selectedIndex = 0;
  MoreSubDestination _moreSubDestination = MoreSubDestination.hub;

  int get selectedIndex => _selectedIndex;
  PrimaryNavTab get currentTab => PrimaryNavTab.fromIndex(_selectedIndex);
  MoreSubDestination get moreSubDestination => _moreSubDestination;

  void selectTab(int index) {
    final clamped = index.clamp(0, 4);
    if (_selectedIndex == clamped && clamped == 4) {
      _moreSubDestination = MoreSubDestination.hub;
      notifyListeners();
      return;
    }
    _selectedIndex = clamped;
    if (clamped != 4) {
      _moreSubDestination = MoreSubDestination.hub;
    }
    notifyListeners();
  }

  /// Backward-compatible navigation helper supporting both 5-tab indices (0..4)
  /// and legacy 7-tab indices used by existing dashboard shortcuts.
  void navigateLegacyOrPrimaryIndex(int index) {
    switch (index) {
      case 0:
        selectTab(0);
        break;
      case 1:
        selectTab(1);
        break;
      case 2:
        openMoreDestination(MoreSubDestination.exerciseLibrary);
        break;
      case 3:
        selectTab(2);
        break;
      case 4:
        openMoreDestination(MoreSubDestination.bodyHealth);
        break;
      case 5:
        selectTab(3);
        break;
      case 6:
        openMoreDestination(MoreSubDestination.settings);
        break;
      default:
        selectTab(index.clamp(0, 4));
    }
  }

  void openMoreDestination(MoreSubDestination sub) {
    _selectedIndex = 4;
    _moreSubDestination = sub;
    notifyListeners();
  }

  void backToMoreHub() {
    if (_moreSubDestination != MoreSubDestination.hub) {
      _moreSubDestination = MoreSubDestination.hub;
      notifyListeners();
    }
  }

  void resetOnSignOut() {
    _selectedIndex = 0;
    _moreSubDestination = MoreSubDestination.hub;
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
    super.dispose();
  }
}
