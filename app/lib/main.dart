import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models/app_release.dart';
import 'services/android_capture_dispatcher.dart';
import 'services/android_saf_vault_storage.dart';
import 'services/android_vault_settings.dart';
import 'services/capture_service.dart';
import 'services/clipboard_service.dart';
import 'services/desktop_file_vault_storage.dart';
import 'services/display_service.dart';
import 'services/settings_service.dart';
import 'services/update_service.dart';
import 'services/vault_storage.dart';
import 'ui/android_settings_view.dart';
import 'ui/capture_pill.dart';
import 'ui/control_center_view.dart';
import 'ui/note_reader_view.dart';
import 'ui/onboarding_view.dart';
import 'ui/update_view.dart';
import 'ui/window_sizes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
    const settings = AndroidVaultSettings();
    const VaultStorage storage = AndroidSafVaultStorage();
    final capture = CaptureService(
      clipboard: ClipboardService(),
      storage: storage,
    );
    await AndroidCaptureDispatcher(
      vaultId: () async {
        final vault = await settings.getVault();
        return vault?.accessible == true ? vault!.id : null;
      },
      capture: capture.captureInput,
    ).start();
    runApp(const AndroidSettingsView(settings: settings));
    return;
  }
  runApp(const InboxApp());
}

class InboxApp extends StatefulWidget {
  final SettingsService? settings;
  final UpdateService? updateService;
  final VaultStorage? storage;

  const InboxApp({super.key, this.settings, this.updateService, this.storage});

  @override
  State<InboxApp> createState() => _InboxAppState();
}

/// 更新页是从哪里进入的——决定关闭后回到桌宠还是控制中心。
enum _UpdateOrigin { pill, controlCenter }

class _InboxAppState extends State<InboxApp> {
  late final SettingsService _settings;
  late final CaptureService _capture;
  late final UpdateService _updates;
  late final VaultStorage _storage;
  late final DisplayService _display;

  String? _vaultPath;
  AppVersion? _currentVersion;
  bool _loading = true;
  bool _showingUpdate = false;
  bool _showingControlCenter = false;
  bool _showingReader = false;
  bool _changingVault = false;
  _UpdateOrigin _updateOrigin = _UpdateOrigin.pill;

  bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings ?? SettingsService();
    _updates = widget.updateService ?? UpdateService();
    _storage = widget.storage ?? const DesktopFileVaultStorage();
    _display = DisplayService(settings: _settings);
    _capture = CaptureService(clipboard: ClipboardService(), storage: _storage);
    // 原生红叉把标准窗口切回悬浮宠物时，复位 Dart 侧的模式状态。
    _settings.setMainWindowClosedHandler(
      _onNativeWindowClosed,
      onTrayAction: _onTrayAction,
    );
    _boot();
  }

  /// 原生关闭按钮 → 悬浮宠物：标准窗口相关模式全部复位。
  void _onNativeWindowClosed() {
    if (!mounted) return;
    setState(() {
      _showingControlCenter = false;
      _showingReader = false;
      _showingUpdate = false;
      _currentVersion = null;
    });
    if (_isWindows) {
      if (_vaultPath == null) {
        _settings.hideWindow();
      } else {
        _restorePetWindow();
      }
    }
  }

  Future<void> _onTrayAction(String action) async {
    if (!mounted || _loading || !_isWindows) return;
    switch (action) {
      case 'changeVault':
        await _changeVault();
      case 'openVault':
        final path = _vaultPath;
        if (path == null) {
          await _settings.showWindow();
        } else if (!await _settings.revealPath(path)) {
          await _settings.showError('无法打开存储文件夹，请检查目录是否仍然存在。');
        }
      case 'checkUpdates':
        await _showUpdates();
    }
  }

  Future<void> _restorePetWindow() async {
    await _settings.setWindowMode('floating');
    await _settings.setWindowSize(
      WindowSizes.pillWidth,
      WindowSizes.pillHeight,
      animate: false,
    );
  }

  Future<void> _boot() async {
    // Windows 可能在启动瞬间遇到尚未就绪的 OneDrive/网络盘。不要因此
    // 永久清除用户选择；实际写入失败会由 CaptureService 给出错误反馈。
    final path = _isWindows
        ? await _settings.getVaultPath()
        : await _settings.loadValidVaultPath();
    if (!mounted) return;
    if (_isWindows) {
      await _settings.setWindowMode(path == null ? 'standard' : 'floating');
      if (!mounted) return;
    }
    setState(() {
      _vaultPath = path;
      _loading = false;
    });
    // 已有存储文件夹：缩回胶囊尺寸。
    if (path != null) {
      _settings.setWindowSize(WindowSizes.pillWidth, WindowSizes.pillHeight);
    }
  }

  Future<void> _onVaultSelected(String path) async {
    setState(() {
      _vaultPath = path;
      _showingControlCenter = false;
      _showingReader = false;
      _showingUpdate = false;
    });
    if (_isWindows) await _settings.setWindowMode('floating');
    await _settings.setWindowSize(
      WindowSizes.pillWidth,
      WindowSizes.pillHeight,
    );
  }

  Future<void> _changeVault() async {
    if (_changingVault) return;
    _changingVault = true;
    if (_isWindows) {
      try {
        await _settings.showWindow();
        final path = await _settings.pickFolder();
        if (!mounted || path == null) return;
        await _storage.ensureLayout(path);
        await _settings.setVaultPath(path);
        if (mounted) await _onVaultSelected(path);
      } catch (error) {
        if (mounted) await _settings.showError('无法更改存储文件夹：$error');
      } finally {
        _changingVault = false;
      }
      return;
    }
    try {
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
    } finally {
      _changingVault = false;
    }
  }

  Future<void> _showUpdates({_UpdateOrigin origin = _UpdateOrigin.pill}) async {
    await _settings.showWindow();
    if (origin == _UpdateOrigin.pill) {
      if (_isWindows) await _settings.setWindowMode('standard');
      await _settings.setWindowSize(
        WindowSizes.updateWidth,
        WindowSizes.updateHeight,
        animate: false,
      );
    }
    // 从控制中心进入：窗口已是 standard 模式，保持当前尺寸只换内容。
    final version = await _settings.getAppVersion();
    if (!mounted) return;
    setState(() {
      _updateOrigin = origin;
      _currentVersion = version;
      _showingUpdate = true;
    });
  }

  Future<void> _closeUpdates() async {
    final origin = _updateOrigin;
    setState(() {
      _showingUpdate = false;
      _currentVersion = null;
    });

    if (origin == _UpdateOrigin.controlCenter) {
      // 回到控制中心，窗口保持 standard 模式与控制中心尺寸。
      return;
    }

    final path = _vaultPath;
    if (path != null) {
      if (_isWindows) await _settings.setWindowMode('floating');
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

  // 控制中心：标准 macOS 窗口，桌宠暂时隐藏。
  Future<void> _openControlCenter() async {
    final path = _vaultPath;
    if (path == null) return;
    // Windows 需要先切换标题栏样式，再按客户区尺寸计算外框。
    if (_isWindows) await _settings.setWindowMode('standard');
    await _settings.setWindowSize(
      WindowSizes.controlCenterWidth,
      WindowSizes.controlCenterHeight,
      animate: false,
    );
    if (!_isWindows) await _settings.setWindowMode('standard');
    if (!mounted) return;
    setState(() => _showingControlCenter = true);
  }

  Future<void> _closeControlCenter() async {
    setState(() {
      _showingControlCenter = false;
      _showingReader = false;
    });
    await _settings.setWindowMode('floating');
    await _settings.setWindowSize(
      WindowSizes.pillWidth,
      WindowSizes.pillHeight,
      animate: false,
    );
  }

  void _openReader() {
    _settings.setWindowSize(WindowSizes.readerWidth, WindowSizes.readerHeight);
    setState(() => _showingReader = true);
  }

  void _closeReader() {
    _settings.setWindowSize(
      WindowSizes.controlCenterWidth,
      WindowSizes.controlCenterHeight,
    );
    setState(() => _showingReader = false);
  }

  @override
  void dispose() {
    _settings.clearDesktopEventHandlers();
    super.dispose();
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

    if (_showingReader && _vaultPath != null) {
      return NoteReaderView(vaultPath: _vaultPath!, onBack: _closeReader);
    }

    if (_showingControlCenter && _vaultPath != null) {
      return ControlCenterView(
        vaultPath: _vaultPath!,
        settings: _settings,
        storage: _storage,
        display: _display,
        onVaultPathChanged: (p) => setState(() => _vaultPath = p),
        onCheckUpdates: () => _showUpdates(origin: _UpdateOrigin.controlCenter),
        onOpenContent: _openReader,
        onClose: _closeControlCenter,
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
      onCheckUpdates: () => _showUpdates(),
      onOpenControlCenter: _openControlCenter,
    );
  }
}
