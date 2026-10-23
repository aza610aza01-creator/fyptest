import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Collects frame timings (estimated FPS, build & raster ms), Android hardware
/// diagnostics via device_info_plus, and scrubbed runtime logs for Admin Tools.
class DiagnosticsService extends ChangeNotifier {
  DiagnosticsService() {
    _attachFrameTimingListener();
  }

  double _estimatedFps = 60.0;
  double _uiBuildMs = 2.4;
  double _rasterMs = 3.1;

  String _deviceModel = 'Unknown';
  String _manufacturer = 'Unknown';
  String _androidVersion = 'Unknown';
  int _sdkLevel = 0;
  String _cpuAbi = 'Unknown';
  bool _isPhysicalDevice = false;

  String _cameraState = 'Idle (Not Initialized)';
  String _detectorState = 'Idle (Closed)';

  final List<String> _runtimeLogs = <String>[];
  bool _timingsRegistered = false;

  double get estimatedFps => _estimatedFps;
  double get uiBuildMs => _uiBuildMs;
  double get rasterMs => _rasterMs;
  String get deviceModel => _deviceModel;
  String get manufacturer => _manufacturer;
  String get androidVersion => _androidVersion;
  int get sdkLevel => _sdkLevel;
  String get cpuAbi => _cpuAbi;
  bool get isPhysicalDevice => _isPhysicalDevice;
  String get cameraState => _cameraState;
  String get detectorState => _detectorState;
  List<String> get runtimeLogs => List.unmodifiable(_runtimeLogs);

  void _attachFrameTimingListener() {
    if (_timingsRegistered) return;
    try {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
      _timingsRegistered = true;
    } catch (_) {
      // Safe fallback during headless unit tests
    }
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    final latest = timings.last;
    final buildMic = latest.buildDuration.inMicroseconds;
    final rasterMic = latest.rasterDuration.inMicroseconds;
    final totalMic = latest.totalSpan.inMicroseconds;

    _uiBuildMs = buildMic / 1000.0;
    _rasterMs = rasterMic / 1000.0;
    if (totalMic > 0) {
      final rawFps = 1000000.0 / totalMic;
      _estimatedFps = rawFps.clamp(1.0, 120.0);
    }
  }

  Future<void> loadDeviceInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final info = await plugin.androidInfo;
        _deviceModel = info.model;
        _manufacturer = info.manufacturer;
        _androidVersion = info.version.release;
        _sdkLevel = info.version.sdkInt;
        _cpuAbi = info.supportedAbis.isNotEmpty
            ? info.supportedAbis.join(', ')
            : 'arm64-v8a';
        _isPhysicalDevice = info.isPhysicalDevice;
      } else {
        _deviceModel = defaultTargetPlatform.name;
        _manufacturer = 'Host Platform';
        _androidVersion = 'N/A';
        _sdkLevel = 0;
        _cpuAbi = 'host';
        _isPhysicalDevice = false;
      }
      logEvent('Loaded device diagnostics for $_manufacturer $_deviceModel');
    } catch (e) {
      logEvent('Device info lookup fallback: ${e.runtimeType}');
    }
    notifyListeners();
  }

  void updateCameraState(String state) {
    _cameraState = state;
    logEvent('Camera state -> $state');
    notifyListeners();
  }

  void updateDetectorState(String state) {
    _detectorState = state;
    logEvent('ML Kit ObjectDetector state -> $state');
    notifyListeners();
  }

  /// Appends a scrubbed entry to the runtime log.
  /// Never logs passwords, OTP codes, tokens, or secrets.
  void logEvent(String rawMessage) {
    final scrubbed = _scrubSensitiveText(rawMessage);
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _runtimeLogs.insert(0, '[$timestamp] $scrubbed');
    if (_runtimeLogs.length > 120) {
      _runtimeLogs.removeLast();
    }
    notifyListeners();
  }

  void clearLogs() {
    _runtimeLogs.clear();
    logEvent('Runtime logs cleared by administrator.');
    notifyListeners();
  }

  String _scrubSensitiveText(String input) {
    var output = input;
    output = output.replaceAll(
      RegExp(r'(password|token|otp|secret|apikey|anonkey)\s*[:=]\s*\S+',
          caseSensitive: false),
      '[REDACTED]',
    );
    output = output.replaceAll(
      RegExp(r'eyJ[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+'),
      '[JWT_REDACTED]',
    );
    return output;
  }
}
