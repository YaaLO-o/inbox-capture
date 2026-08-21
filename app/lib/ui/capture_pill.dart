import 'package:flutter/material.dart';

import '../services/capture_service.dart';
import '../services/settings_service.dart';
import 'window_sizes.dart';

/// 悬浮入口胶囊：点击即读取剪贴板并保存（见《方案》第十一节）。
class CapturePill extends StatefulWidget {
  final String vaultPath;
  final CaptureService capture;
  final void Function() onChangeVault;

  const CapturePill({
    super.key,
    required this.vaultPath,
    required this.capture,
    required this.onChangeVault,
  });

  @override
  State<CapturePill> createState() => _CapturePillState();
}

class _CapturePillState extends State<CapturePill> {
  bool _busy = false;
  String? _flash;
  Color? _flashColor;

  @override
  void initState() {
    super.initState();
    // 缩回小胶囊。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 尺寸由原生窗口在创建时给定；这里无需再次调整，但保留钩子。
    });
  }

  Future<void> _doCapture() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.capture.captureNow(widget.vaultPath);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result.status) {
        case CaptureStatus.saved:
          _flash = '✓ 已保存';
          _flashColor = const Color(0xFF2E7D4F);
          break;
        case CaptureStatus.empty:
          _flash = result.message ?? '剪贴板为空';
          _flashColor = const Color(0xFF6E6E78);
          break;
        case CaptureStatus.error:
          _flash = '保存失败';
          _flashColor = const Color(0xFFB23B3B);
          break;
      }
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  void _showMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: const Color(0xFF2A2A33),
      items: const [
        PopupMenuItem(value: 'vault', child: Text('重新选择 Vault', style: TextStyle(fontSize: 12.5))),
        PopupMenuItem(value: 'quit', child: Text('退出', style: TextStyle(fontSize: 12.5))),
      ],
    ).then((v) {
      if (!mounted) return;
      if (v == 'vault') widget.onChangeVault();
      if (v == 'quit') {
        _settings.quit();
      }
    });
  }

  // 仅用于退出等系统操作。
  static final SettingsService _settings = SettingsService();

  @override
  Widget build(BuildContext context) {
    final label = _flash ?? (_busy ? '保存中…' : '采集');
    final color = _flashColor ?? const Color(0xFF7C5CFF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GestureDetector(
            onTap: _doCapture,
            onSecondaryTapUp: (d) => _showMenu(context, d.globalPosition),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: WindowSizes.pillWidth - 16,
              height: WindowSizes.pillHeight - 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_busy)
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
