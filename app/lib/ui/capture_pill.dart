import 'package:flutter/material.dart';

import '../services/capture_service.dart';
import '../services/settings_service.dart';

/// 两个平台共用的低摩擦悬浮采集入口。
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
  static final SettingsService _settings = SettingsService();

  bool _busy = false;
  String? _flash;

  Future<void> _doCapture() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.capture.captureNow(widget.vaultPath);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _flash = switch (result.status) {
        CaptureStatus.saved => '已保存',
        CaptureStatus.empty => result.message ?? '剪贴板为空',
        CaptureStatus.error => '保存失败',
      };
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  void _showMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: const Color(0xFF2A2A33),
      items: const [
        PopupMenuItem(
          value: 'vault',
          child: Text('重新选择 Vault', style: TextStyle(fontSize: 12.5)),
        ),
        PopupMenuItem(
          value: 'quit',
          child: Text('退出', style: TextStyle(fontSize: 12.5)),
        ),
      ],
    ).then((value) {
      if (!mounted) return;
      if (value == 'vault') widget.onChangeVault();
      if (value == 'quit') _settings.quit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _flash ?? (_busy ? '正在保存…' : '点击保存');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (menuContext) => Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapUp: (details) =>
                _showMenu(menuContext, details.globalPosition),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DragHandle(
                    onMove: (dx, dy) => _settings.moveWindowBy(dx, dy),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _doCapture,
                    child: AnimatedScale(
                      scale: _busy ? 0.96 : 1,
                      duration: const Duration(milliseconds: 120),
                      child: _CaptureButton(busy: _busy),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusLabel(text: status),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  final void Function(double dx, double dy) onMove;

  const _DragHandle({required this.onMove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => onMove(details.delta.dx, details.delta.dy),
      child: Container(
        width: 44,
        height: 14,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xEEFFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24372768),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          '•••',
          style: TextStyle(
            color: Color(0xBF44366E),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            height: 0.8,
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool busy;

  const _CaptureButton({required this.busy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF7D6), Color(0xFFFFD98C)],
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D372768),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF3C2F68),
              ),
            )
          else ...[
            const Text(
              '•  •',
              style: TextStyle(
                color: Color(0xFF3C2F68),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '收',
              style: TextStyle(
                color: Color(0xFF3C2F68),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final String text;

  const _StatusLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 116),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26372768),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF44366E),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
