import 'package:flutter/material.dart';

import 'services/capture_service.dart';
import 'services/clipboard_service.dart';
import 'services/settings_service.dart';
import 'services/storage_service.dart';
import 'ui/capture_pill.dart';
import 'ui/onboarding_view.dart';
import 'ui/window_sizes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InboxApp());
}

class InboxApp extends StatefulWidget {
  const InboxApp({super.key});

  @override
  State<InboxApp> createState() => _InboxAppState();
}

class _InboxAppState extends State<InboxApp> {
  final SettingsService _settings = SettingsService();
  late final CaptureService _capture;

  String? _vaultPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Color(0xFF1E1E24)),
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
    );
  }
}
