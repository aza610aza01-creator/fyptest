import 'package:flutter/foundation.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/services/auth_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Manages authentication stage transitions, 2-step Email OTP gate, and
/// safe Guest-to-Cloud account upgrade without losing local guest records.
class AuthFlowController extends ChangeNotifier {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  AuthFlowController({
    required this.authService,
    required this.prefs,
  }) {
    authService.addListener(_onAuthChanged);
  }

  final AuthService authService;
  final PreferenceService prefs;

  bool _openRegisterOnAuth = false;
  bool get openRegisterOnAuth => _openRegisterOnAuth;

  AppUser get currentUser => authService.currentUser;

  void _onAuthChanged() {
    if (currentUser.isFullyAuthenticated) {
      _openRegisterOnAuth = false;
    }
    notifyListeners();
  }

  /// Prepares Guest-to-Cloud upgrade: marks local guest records for migration
  /// and opens the Create Account tab on AuthScreen without wiping local data.
  Future<void> beginGuestUpgradeToCloud() async {
    _openRegisterOnAuth = true;
    await prefs.setPendingGuestMigration(true);
    await authService.signOut();
    notifyListeners();
  }

  void clearRegisterFlag() {
    if (_openRegisterOnAuth) {
      _openRegisterOnAuth = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    authService.removeListener(_onAuthChanged);
    super.dispose();
  }
}
