import 'package:flutter/material.dart';

import 'models/app_release.dart';
import 'services/capture_service.dart';
import 'services/clipboard_service.dart';
import 'services/settings_service.dart';
import 'services/storage_service.dart';
import 'services/update_service.dart';
import 'ui/capture_pill.dart';
import 'ui/onboarding_view.dart';
import 'ui/update_view.dart';
import 'ui/window_sizes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InboxApp());
}

class InboxApp extends StatefulWidget {
  final SettingsService? settings;
  final UpdateService? updateService;

  const InboxApp({
    super.key,
    this.settings,
    this.updateService,
  });

  @override
  State<InboxApp> createState() => _InboxAppState();
}

class _InboxAppState extends State<InboxApp> {
  late final SettingsService _settings;
  late final CaptureService _capture;
  late final UpdateService _updates;

  String? _vaultPath;
  AppVersion? _currentVersion;
  bool _loading = true;
  bool _showingUpdate = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings ?? SettingsService();
    _updates = widget.updateService ?? UpdateService();
    _capture = CaptureService(
      clipboard: ClipboardService(),
      storage: StorageService(),
    );
    _boot();
  }

  Future<void> _boot() async {
    final path = await _settings.loadValidVaultPath();
    if (!mounted) return;
    setState(() {
      _vaultPath = path;
      _loading = false;
    });
    // 已有 Vault：缩回胶囊尺寸。
    if (path != null) {
      _settings.setWindowSize(WindowSizes.pillWidth, WindowSizes.pillHeight);
    }
  }

  Future<void> _onVaultSelected(String path) async {
    setState(() => _vaultPath = path);
    await _settings.setWindowSize(
      WindowSizes.pillWidth,
      WindowSizes.pillHeight,
    );
  }

  Future<void> _changeVault() async {
    await _settings.setWindowSize(
      WindowSizes.onboardingWidth,
      WindowSizes.onboardingHeight,
    );
    final path = await _settings.pickFolder();
    if (!mounted) return;
    if (path != null) {
      await _settings.setVaultPath(path);
      if (!mounted) return;
      await _onVaultSelected(path);
    } else if (_vaultPath != null) {
      // 取消选择，回到胶囊。
      await _settings.setWindowSize(
        WindowSizes.pillWidth,
        WindowSizes.pillHeight,
      );
    }
  }

  Future<void> _showUpdates() async {
    await _settings.showWindow();
    await _settings.setWindowSize(
      WindowSizes.updateWidth,
      WindowSizes.updateHeight,
      animate: false,
    );
    final version = await _settings.getAppVersion();
    if (!mounted) return;
    setState(() {
      _currentVersion = version;
      _showingUpdate = true;
    });
  }

  Future<void> _closeUpdates() async {
    setState(() {
      _showingUpdate = false;
      _currentVersion = null;
    });

    final path = _vaultPath;
    if (path != null) {
      await _settings.setWindowSize(
        WindowSizes.pillWidth,
        WindowSizes.pillHeight,
        animate: false,
      );
    } else {
      await _settings.setWindowSize(
        WindowSizes.onboardingWidth,
        WindowSizes.onboardingHeight,
        animate: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Color(0xFF1E1E24)),
      );
    }

    final currentVersion = _currentVersion;
    if (_showingUpdate && currentVersion != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF43C6AC),
          fontFamily: '.AppleSystemUIFont',
        ),
        home: UpdateView(
          currentVersion: currentVersion,
          service: _updates,
          installer: _settings.installUpdate,
          onClose: _closeUpdates,
        ),
      );
    }

    final path = _vaultPath;
    if (path == null) {
      return OnboardingView(
        settings: _settings,
        onVaultSelected: _onVaultSelected,
      );
    }

    return CapturePill(
      vaultPath: path,
      capture: _capture,
      onChangeVault: _changeVault,
      onCheckUpdates: _showUpdates,
    );
  }
}
