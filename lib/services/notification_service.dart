import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Manages the workout Rest Timer, +/- duration adjustments, workout reminders,
/// and streak warnings with haptic/system sound feedback.
class NotificationService extends ChangeNotifier {
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  int _totalSeconds = 90;
  bool _isRunning = false;
  String? _activeBannerMessage;

  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  bool get isRunning => _isRunning;
  String? get activeBannerMessage => _activeBannerMessage;

  double get progress {
    if (_totalSeconds <= 0) return 0;
    return (_remainingSeconds / _totalSeconds).clamp(0.0, 1.0);
  }

  String get formattedRemaining {
    final mins = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void startRestTimer(int seconds, {bool isZh = false}) {
    _countdownTimer?.cancel();
    _totalSeconds = seconds.clamp(5, 1800);
    _remainingSeconds = _totalSeconds;
    _isRunning = true;
    _activeBannerMessage = null;
    notifyListeners();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        _remainingSeconds -= 1;
        notifyListeners();
      } else {
        timer.cancel();
        _remainingSeconds = 0;
        _isRunning = false;
        _activeBannerMessage = isZh
            ? '組間休息結束！準備開始下一組訓練。'
            : 'Rest timer complete! Ready for your next set.';
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.alert);
        notifyListeners();
      }
    });
  }

  void adjustRestSeconds(int deltaSeconds) {
    if (!_isRunning && _remainingSeconds == 0) {
      _totalSeconds = (_totalSeconds + deltaSeconds).clamp(15, 600);
      notifyListeners();
      return;
    }
    _remainingSeconds = (_remainingSeconds + deltaSeconds).clamp(0, 1800);
    if (_remainingSeconds > _totalSeconds) {
      _totalSeconds = _remainingSeconds;
    }
    if (_remainingSeconds == 0) {
      stopRestTimer();
    } else {
      notifyListeners();
    }
  }

  void stopRestTimer() {
    _countdownTimer?.cancel();
    _remainingSeconds = 0;
    _isRunning = false;
    notifyListeners();
  }

  void dismissBanner() {
    _activeBannerMessage = null;
    notifyListeners();
  }

  void triggerStreakWarning({required int currentStreak, required bool isZh}) {
    _activeBannerMessage = isZh
        ? '連勝提醒：您目前連續訓練 $currentStreak 天，今日完成一組即可延續紀錄！'
        : 'Streak Alert: You are on a $currentStreak-day streak. Log a session today to keep it alive!';
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
