import 'package:flutter/material.dart';

import '../models/app_release.dart';
import '../services/update_service.dart';

typedef UpdateInstaller = Future<void> Function(String dmgPath);

enum _UpdateState {
  checking,
  available,
  downloading,
  installing,
  current,
  error,
}

class UpdateView extends StatefulWidget {
  final AppVersion currentVersion;
  final UpdateService service;
  final UpdateInstaller installer;
  final VoidCallback onClose;

  const UpdateView({
    super.key,
    required this.currentVersion,
    required this.service,
    required this.installer,
    required this.onClose,
  });

  @override
  State<UpdateView> createState() => _UpdateViewState();
}

class _UpdateViewState extends State<UpdateView> {
  _UpdateState _state = _UpdateState.checking;
  AppRelease? _release;
  DownloadProgress? _progress;
  bool _operationActive = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final release = await widget.service.fetchLatest();
      if (!mounted) return;
      setState(() {
        _release = release;
        _state = release.version.compareTo(widget.currentVersion) > 0
            ? _UpdateState.available
            : _UpdateState.current;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _UpdateState.error);
    }
  }

  Future<void> _downloadAndInstall() async {
    final release = _release;
    if (release == null || _state != _UpdateState.available) return;

    setState(() {
      _state = _UpdateState.downloading;
      _progress = null;
      _operationActive = true;
    });

    try {
      final file = await widget.service.download(
        release,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _state = _UpdateState.installing;
      });
      await widget.installer(file.path);
      if (!mounted) return;
      setState(() => _operationActive = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _UpdateState.error;
        _operationActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canClose = !_operationActive;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E24),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'INbox 更新',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(child: _buildContent()),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canClose ? widget.onClose : null,
                    child: const Text('关闭'),
                  ),
                ),
                if (_state == _UpdateState.available) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _downloadAndInstall,
                      child: const Text('下载并安装'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _UpdateState.checking:
        return const _StatusText('正在检查更新…');
      case _UpdateState.available:
        return _StatusText('发现新版本 ${_release!.version}');
      case _UpdateState.downloading:
        return _DownloadStatus(progress: _progress);
      case _UpdateState.installing:
        return const _StatusText('正在完成安装，INbox 将重新启动…');
      case _UpdateState.current:
        return const _StatusText('当前已是最新版本');
      case _UpdateState.error:
        return const _StatusText('校验失败，已保留当前版本');
    }
  }
}

class _StatusText extends StatelessWidget {
  final String text;

  const _StatusText(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
      ),
    );
  }
}

class _DownloadStatus extends StatelessWidget {
  final DownloadProgress? progress;

  const _DownloadStatus({required this.progress});

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    final hasTotal = progress != null && progress.total > 0;
    final value = hasTotal
        ? (progress.received / progress.total).clamp(0.0, 1.0)
        : null;
    final percent = hasTotal ? '${(value! * 100).round()}%' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '正在下载更新…',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(value: value),
        if (percent != null) ...[
          const SizedBox(height: 10),
          Text(
            percent,
            style: const TextStyle(color: Color(0xFFB7B7C2), fontSize: 13),
          ),
        ],
      ],
    );
  }
}
