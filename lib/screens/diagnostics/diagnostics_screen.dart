import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/constants/app_config.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/services/database_service.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';

/// Admin Developer Tools screen (Section 22).
/// Strictly gated: only accessible when `user.isAdmin` is true
/// (verified Email == ADMIN_EMAIL + password + verified Email OTP, never Guest).
/// Never displays passwords, OTPs, access/refresh tokens, service_role, or full Publishable Key.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    super.key,
    required this.user,
    required this.config,
    required this.diagnostics,
    required this.dbService,
    required this.prefs,
  });

  final AppUser user;
  final AppConfig config;
  final DiagnosticsService diagnostics;
  final DatabaseService dbService;
  final PreferenceService prefs;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String _authTestStatus = 'Not run yet';
  String _dbTestStatus = 'Not run yet';
  bool _runningTests = false;

  @override
  void initState() {
    super.initState();
    widget.diagnostics.loadDeviceInfo();
  }

  Future<void> _runLiveDiagnostics() async {
    setState(() => _runningTests = true);
    final authRes = await widget.dbService.runAuthConnectionTest();
    final dbRes = await widget.dbService.runDatabaseReadWriteTest(
      widget.user.id,
    );
    if (!mounted) return;
    setState(() {
      _authTestStatus = authRes;
      _dbTestStatus = dbRes;
      _runningTests = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isZh = widget.prefs.languageCode.startsWith('zh');
    final glass = widget.prefs.glassThemeEnabled;

    // Hard server/role guard: never allow standard or Guest users
    if (!widget.user.isAdmin || widget.user.isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Administrator access requires a verified account matching ADMIN_EMAIL with verified Email OTP.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isZh ? '管理員開發者診斷工具' : 'Admin Developer Tools',
        ),
        actions: [
          IconButton(
            tooltip: isZh ? '執行連線測試' : 'Run Connection Tests',
            onPressed: _runningTests ? null : _runLiveDiagnostics,
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: GlassScaffoldBackground(
        glassEnabled: glass,
        child: ListenableBuilder(
          listenable: widget.diagnostics,
          builder: (context, _) {
            final d = widget.diagnostics;
            final prefSnap = widget.prefs.diagnosticsSnapshot();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassPanel(
                  glassEnabled: glass,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: isZh
                            ? '即時渲染效能估算 (FPS / Build / Raster)'
                            : 'Performance Estimates (Recommend Profile Mode)',
                        icon: Icons.speed,
                      ),
                      Text(
                        isZh
                            ? '註：FPS 數值為估算值，建議使用 Flutter Profile Mode 進行精確效能分析。'
                            : 'Note: FPS values are labelled estimates. Use Flutter Profile Mode for reliable performance measurement.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      _kvRow('Estimated FPS', '${d.estimatedFps.toStringAsFixed(1)} FPS (Estimate)'),
                      _kvRow('UI Build Time', '${d.uiBuildMs.toStringAsFixed(2)} ms'),
                      _kvRow('Raster Time', '${d.rasterMs.toStringAsFixed(2)} ms'),
                      _kvRow('Build Mode', AppConfig.buildModeName),
                    ],
                  ),
                ),
                GlassPanel(
                  glassEnabled: glass,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Supabase & Security Diagnostics',
                        icon: Icons.security,
                      ),
                      _kvRow(
                        'Supabase Project',
                        widget.config.supabaseProjectName,
                      ),
                      _kvRow(
                        'Supabase Organization',
                        widget.config.supabaseOrgName,
                      ),
                      _kvRow(
                        'Supabase Configured',
                        widget.config.isConfigured ? 'YES' : 'NO',
                      ),
                      _kvRow('Supabase URL', widget.config.supabaseUrl),
                      _kvRow(
                        'Publishable Key (Masked)',
                        widget.config.maskedPublishableKey,
                      ),
                      _kvRow(
                        'Session Status',
                        widget.user.stage.name.toUpperCase(),
                      ),
                      _kvRow(
                        'Current User ID (Masked)',
                        AppConfig.maskUserId(widget.user.id),
                      ),
                      _kvRow(
                        'Verified Admin Email (Masked)',
                        AppConfig.maskEmail(widget.user.email),
                      ),
                      _kvRow('Auth Connection Test', _authTestStatus),
                      _kvRow('DB Read/Write Test', _dbTestStatus),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _runningTests ? null : _runLiveDiagnostics,
                        icon: const Icon(Icons.network_check),
                        label: Text(
                          isZh
                              ? '執行 Supabase Auth 與資料庫讀寫測試'
                              : 'Run Supabase Auth & Database R/W Test',
                        ),
                      ),
                    ],
                  ),
                ),
                GlassPanel(
                  glassEnabled: glass,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Android Device Info (device_info_plus)',
                        icon: Icons.phone_android,
                      ),
                      _kvRow('Device Model', d.deviceModel),
                      _kvRow('Manufacturer', d.manufacturer),
                      _kvRow('Android Version', d.androidVersion),
                      _kvRow('SDK Level', '${d.sdkLevel}'),
                      _kvRow('CPU ABI', d.cpuAbi),
                      _kvRow(
                        'Hardware Type',
                        d.isPhysicalDevice ? 'Physical Device' : 'Emulator / Host',
                      ),
                    ],
                  ),
                ),
                GlassPanel(
                  glassEnabled: glass,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Camera, YOLOv8 / ML Kit & Preferences State',
                        icon: Icons.tune,
                      ),
                      _kvRow('Camera State', d.cameraState),
                      _kvRow('YOLO / Object Detector State', d.detectorState),
                      _kvRow('Last Sync State', widget.prefs.lastSyncState),
                      for (final entry in prefSnap.entries)
                        _kvRow('Pref: ${entry.key}', '${entry.value}'),
                    ],
                  ),
                ),
                GlassPanel(
                  glassEnabled: glass,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Scrubbed Runtime Log (${d.runtimeLogs.length})',
                        icon: Icons.terminal,
                        trailing: TextButton.icon(
                          onPressed: d.clearLogs,
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: Text(isZh ? '清除日誌' : 'Clear Logs'),
                        ),
                      ),
                      if (d.runtimeLogs.isEmpty)
                        const Text('No runtime log entries.')
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: d.runtimeLogs.length,
                            itemBuilder: (_, idx) => Text(
                              d.runtimeLogs[idx],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
