import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Manages the workout Rest Timer using absolute UTC end timestamps so that
/// backgrounding, lifecycle pauses, or app restarts recover remaining seconds
/// accurately without duplicate timers or duplicate notifications.
class NotificationService extends ChangeNotifier {
  Timer? _countdownTimer;
  DateTime? _targetEndUtc;
  int _remainingSeconds = 0;
  int _totalSeconds = 90;
  bool _isRunning = false;
  bool _hapticsEnabled = true;
  String? _activeBannerMessage;

  int get remainingSeconds => _remainingSeconds;
  int get remainingRestSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  bool get isRunning => _isRunning;
  bool get hapticsEnabled => _hapticsEnabled;
  DateTime? get targetEndUtc => _targetEndUtc;
  String? get activeBannerMessage => _activeBannerMessage;

  void setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
  }

  double get progress {
    if (_totalSeconds <= 0) return 0;
    return (_remainingSeconds / _totalSeconds).clamp(0.0, 1.0);
  }

  String get formattedRemaining {
    final mins = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void startRestTimer(
    int seconds, {
    bool isZh = false,
    DateTime? nowOverrideUtc,
  }) {
    _countdownTimer?.cancel();
    _totalSeconds = seconds.clamp(5, 1800);
    _remainingSeconds = _totalSeconds;
    final nowUtc = (nowOverrideUtc ?? DateTime.now()).toUtc();
    _targetEndUtc = nowUtc.add(Duration(seconds: _totalSeconds));
    _isRunning = true;
    _activeBannerMessage = null;
    notifyListeners();

    _attachPeriodicTicker(isZh: isZh);
  }

  /// Recovers an active rest timer from an absolute UTC end timestamp after
  /// app restart or lifecycle resume.
  void recoverFromTimestamp(
    DateTime? targetEndUtc, {
    int totalSeconds = 90,
    bool isZh = false,
    DateTime? nowOverrideUtc,
  }) {
    _countdownTimer?.cancel();
    if (targetEndUtc == null) return;
    final nowUtc = (nowOverrideUtc ?? DateTime.now()).toUtc();
    final diffSeconds = targetEndUtc.toUtc().difference(nowUtc).inSeconds;
    _totalSeconds = totalSeconds.clamp(5, 1800);

    if (diffSeconds <= 0) {
      _targetEndUtc = null;
      _remainingSeconds = 0;
      _isRunning = false;
      _activeBannerMessage = isZh
          ? '組間休息結束！準備開始下一組訓練。'
          : 'Rest timer complete! Ready for your next set.';
      notifyListeners();
      return;
    }

    _targetEndUtc = targetEndUtc.toUtc();
    _remainingSeconds = diffSeconds.clamp(1, 1800);
    if (_remainingSeconds > _totalSeconds) {
      _totalSeconds = _remainingSeconds;
    }
    _isRunning = true;
    notifyListeners();
    _attachPeriodicTicker(isZh: isZh);
  }

  void _attachPeriodicTicker({required bool isZh}) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nowUtc = DateTime.now().toUtc();
      final computedRemaining = _targetEndUtc != null
          ? _targetEndUtc!.difference(nowUtc).inSeconds
          : (_remainingSeconds - 1);

      if (computedRemaining > 0) {
        _remainingSeconds = computedRemaining;
        notifyListeners();
      } else {
        timer.cancel();
        _targetEndUtc = null;
        _remainingSeconds = 0;
        _isRunning = false;
        _activeBannerMessage = isZh
            ? '組間休息結束！準備開始下一組訓練。'
            : 'Rest timer complete! Ready for your next set.';
        if (_hapticsEnabled) {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.alert);
        }
        notifyListeners();
      }
    });
  }

  void onAppLifecycleChanged(AppLifecycleState state, {bool isZh = false}) {
    if (state == AppLifecycleState.resumed && _targetEndUtc != null) {
      recoverFromTimestamp(
        _targetEndUtc,
        totalSeconds: _totalSeconds,
        isZh: isZh,
      );
    }
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
      _targetEndUtc =
          DateTime.now().toUtc().add(Duration(seconds: _remainingSeconds));
      notifyListeners();
    }
  }

  void stopRestTimer() {
    _countdownTimer?.cancel();
    _targetEndUtc = null;
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
