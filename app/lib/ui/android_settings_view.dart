import 'package:flutter/material.dart' hide OverlayState;

import '../services/android_vault_settings.dart';

class AndroidSettingsView extends StatefulWidget {
  final AndroidVaultSettings settings;

  const AndroidSettingsView({
    super.key,
    this.settings = const AndroidVaultSettings(),
  });

  @override
  State<AndroidSettingsView> createState() => _AndroidSettingsViewState();
}

class _AndroidSettingsViewState extends State<AndroidSettingsView>
    with WidgetsBindingObserver {
  VaultDescriptor? _vault;
  OverlayState? _overlay;
  bool _loading = true;
  String? _statusMessage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Permission settings returns here; refresh overlay + vault state.
      _refreshOverlay();
    }
  }

  Future<void> _loadAll() async {
    VaultDescriptor? vault;
    OverlayState? overlay;
    try {
      vault = await widget.settings.getVault();
    } catch (_) {}
    try {
      overlay = await widget.settings.getOverlayState();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _vault = vault;
      _overlay = overlay;
      _loading = false;
    });
  }

  Future<void> _refreshOverlay() async {
    try {
      final state = await widget.settings.getOverlayState();
      if (!mounted) return;
      setState(() {
        _overlay = state;
      });
    } catch (_) {
      // Leave previous state visible if the refresh fails transiently.
    }
  }

  Future<void> _pickVault() async {
    final vault = await widget.settings.pickVault();
    if (!mounted || vault == null) return;
    setState(() {
      _vault = vault;
    });
    await _refreshOverlay();
  }

  Future<void> _requestOverlayPermission() async {
    await widget.settings.requestOverlayPermission();
    // The user is now leaving for system settings; state will refresh on
    // resume. Do NOT optimistically call startOverlay here — the brief says
    // to only start when permission is already granted.
    if (!mounted) return;
    await _refreshOverlay();
  }

  Future<void> _requestNotificationPermission() async {
    await widget.settings.requestNotificationPermission();
    if (!mounted) return;
    await _refreshOverlay();
  }

  Future<void> _openNotificationSettings() async {
    await widget.settings.openNotificationSettings();
  }

  Future<void> _toggleOverlay() async {
    if (_busy) return;
    final overlay = _overlay;
    if (overlay == null) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      if (overlay.running) {
        await widget.settings.stopOverlay();
      } else {
        // Ensure overlay permission is granted before attempting to start.
        // requestOverlayPermission returns synchronously when already granted
        // and launches system settings otherwise.
        final granted = await widget.settings.requestOverlayPermission();
        if (!granted) {
          if (!mounted) return;
          setState(() {
            _statusMessage = '请先授予"显示在其他应用上层"权限';
            _busy = false;
          });
          await _refreshOverlay();
          return;
        }
        await widget.settings.startOverlay();
      }
      if (!mounted) return;
      await _refreshOverlay();
    } on OverlayException catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = _overlayErrorMessage(error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = '悬浮球操作失败: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _overlayErrorMessage(OverlayException error) {
    switch (error.code) {
      case 'OVERLAY_PERMISSION_DENIED':
        return '请先授予"显示在其他应用上层"权限';
      case 'VAULT_UNAVAILABLE':
        return '请先选择 Vault';
      case 'NOTIFICATION_PERMISSION_DENIED':
        return '通知权限被拒绝，悬浮球仍将运行';
      case 'NO_ACTIVITY':
        return '请在 App 前台时重试';
      default:
        return error.message ?? '悬浮球操作失败';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF222222),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final overlay = _overlay;
    final running = overlay?.running ?? false;
    final overlayPermission = overlay?.overlayPermission ?? false;
    final notificationPermission = overlay?.notificationPermission ?? true;
    final vaultConfigured =
        overlay?.vaultConfigured ?? (_vault != null);
    final canStart = vaultConfigured && !running;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Vault', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(_vault?.displayName ?? '尚未选择'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _pickVault,
          child: const Text('重新选择 Vault'),
        ),
        const SizedBox(height: 32),
        Text(
          '悬浮 Capture',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        _PermissionRow(
          label: '显示在其他应用上层',
          granted: overlayPermission,
          actionLabel: '去设置',
          onAction: _requestOverlayPermission,
        ),
        _PermissionRow(
          label: '通知',
          granted: notificationPermission,
          actionLabel: '去设置',
          onAction: notificationPermission
              ? null
              : () async {
                  await _requestNotificationPermission();
                  if (!mounted) return;
                  // If the system silently denied, take the user to app
                  // notification settings as a fallback.
                  final refreshed = _overlay;
                  if (refreshed != null &&
                      !refreshed.notificationPermission) {
                    await _openNotificationSettings();
                  }
                },
        ),
        if (!vaultConfigured)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '请先选择 Vault 后再开启悬浮球',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: (_busy || (!canStart && !running))
              ? null
              : _toggleOverlay,
          child: Text(running ? '停止悬浮球' : '开启悬浮球'),
        ),
        const SizedBox(height: 12),
        Text(
          running ? '悬浮球运行中' : '悬浮球未开启',
          style: const TextStyle(color: Colors.black87),
        ),
        if (!notificationPermission)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '通知权限未授予，悬浮球仍会运行，但不会显示常驻通知。',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _statusMessage!,
            style: const TextStyle(color: Color(0xFFB00020)),
          ),
        ],
        const SizedBox(height: 32),
        Text('权限', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          _vault?.accessible == true
              ? 'Vault 可读写'
              : '需要 Vault 读写权限',
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String label;
  final bool granted;
  final String actionLabel;
  final VoidCallback? onAction;

  const _PermissionRow({
    required this.label,
    required this.granted,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              granted ? '已授予' : '未授予',
              style: TextStyle(
                color: granted ? Colors.black87 : Colors.black54,
              ),
            ),
          ),
          if (!granted)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}
