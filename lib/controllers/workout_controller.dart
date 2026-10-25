import 'package:flutter/foundation.dart';
import 'package:ai_gym_flutter/services/notification_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Coordinates active workout draft autosave, crash recovery, and timestamp-based
/// rest timer persistence across app restarts.
class WorkoutController extends ChangeNotifier {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  WorkoutController({
    required this.prefs,
    required this.notifications,
  }) {
    _recoverableDraft = prefs.getWorkoutDraft();
  }

  final PreferenceService prefs;
  final NotificationService notifications;

  WorkoutDraftData? _recoverableDraft;
  bool _isSubmittingWorkout = false;

  WorkoutDraftData? get recoverableDraft => _recoverableDraft;
  bool get hasRecoverableDraft =>
      _recoverableDraft != null && _recoverableDraft!.sets.isNotEmpty;
  bool get isSubmittingWorkout => _isSubmittingWorkout;

  void refreshDraftForUser(String userId) {
    _recoverableDraft = prefs.getWorkoutDraft(userId);
    notifyListeners();
  }

  Future<void> autosaveDraft(WorkoutDraftData draft) async {
    _recoverableDraft = draft;
    await prefs.saveWorkoutDraft(draft);
    if (notifications.targetEndUtc != null) {
      await prefs.setRestTimerEndUtc(notifications.targetEndUtc);
    }
    notifyListeners();
  }

  Future<void> discardDraft([String? userId]) async {
    _recoverableDraft = null;
    await prefs.clearWorkoutDraft(userId);
    notifyListeners();
  }

  void setSubmitting(bool busy) {
    _isSubmittingWorkout = busy;
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
