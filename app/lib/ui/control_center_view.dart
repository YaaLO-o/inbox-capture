import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_release.dart';
import '../services/display_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../util/path_utils.dart';

/// 控制中心：Mac 主页面，承担"控制中心"角色。
///
/// 只放最必要内容：当前存储位置、打开/更改存储文件夹、默认展示方式、
/// 查看内容、检查更新。不做笔记内容管理。
class ControlCenterView extends StatefulWidget {
  final String vaultPath;
  final SettingsService settings;
  final StorageService storage;
  final DisplayService display;
  final void Function(String newPath) onVaultPathChanged;
  final VoidCallback onCheckUpdates;
  final VoidCallback onOpenContent;
  final VoidCallback onClose;

  const ControlCenterView({
    super.key,
    required this.vaultPath,
    required this.settings,
    required this.storage,
    required this.display,
    required this.onVaultPathChanged,
    required this.onCheckUpdates,
    required this.onOpenContent,
    required this.onClose,
  });

  @override
  State<ControlCenterView> createState() => _ControlCenterViewState();
}

class _ControlCenterViewState extends State<ControlCenterView> {
  DisplayMethod _method = DisplayMethod.inbox;
  bool _loadingPref = true;
  bool _changingFolder = false;
  String? _folderError;
  Future<AppVersion>? _versionFuture;

  @override
  void initState() {
    super.initState();
    _loadPref();
    _versionFuture = widget.settings.getAppVersion();
  }

  Future<void> _loadPref() async {
    final method = await widget.display.load();
    if (!mounted) return;
    setState(() {
      _method = method;
      _loadingPref = false;
    });
  }

  Future<void> _selectMethod(DisplayMethod method) async {
    setState(() => _method = method);
    await widget.display.save(method);
  }

  Future<void> _openFolder() async {
    await widget.settings.revealPath(widget.vaultPath);
  }

  Future<void> _openContent() async {
    final method = await widget.display.load();
    if (!mounted) return;
    if (method == DisplayMethod.inbox) {
      widget.onOpenContent();
      return;
    }
    final result =
        await widget.display.openDailyNoteExternally(widget.vaultPath, DateTime.now());
    if (!mounted) return;
    switch (result) {
      case OpenNoteResult.opened:
        break;
      case OpenNoteResult.obsidianMissing:
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('未检测到 Obsidian'),
            content: const Text(
              '系统中没有能打开 obsidian:// 链接的应用。'
              '可以改用系统默认 Markdown 应用打开。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final today = DateTime.now();
                  final file = File(
                    '${VaultPaths.captureDir(widget.vaultPath)}/'
                    '${today.year.toString().padLeft(4, '0')}-'
                    '${today.month.toString().padLeft(2, '0')}-'
                    '${today.day.toString().padLeft(2, '0')}.md',
                  );
                  if (file.existsSync()) {
                    await widget.settings.openPath(file.path);
                  }
                },
                child: const Text('用系统默认应用打开'),
              ),
            ],
          ),
        );
        break;
      case OpenNoteResult.fileMissing:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('今日还没有采集内容'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  Future<void> _changeFolder() async {
    setState(() {
      _changingFolder = true;
      _folderError = null;
    });
    try {
      final path = await widget.settings.pickFolder();
      if (!mounted) return;
      if (path == null) {
        // 用户取消，不做任何事。
        return;
      }
      // 选择新的真实数据目录：在新位置建好布局，绝不搬旧文件，
      // 也不写任何 Obsidian 配置。
      widget.storage.ensureVaultLayout(path);
      await widget.settings.setVaultPath(path);
      if (!mounted) return;
      widget.onVaultPathChanged(path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _folderError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _changingFolder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF43C6AC),
        fontFamily: '.AppleSystemUIFont',
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF1E1E24),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '控制中心',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel('存储位置'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A33),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: const Color(0xFF3A3A45)),
                        ),
                        child: SelectableText(
                          widget.vaultPath,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openFolder,
                              icon: const Icon(Icons.folder_outlined, size: 16),
                              label: const Text('打开存储文件夹'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _changingFolder ? null : _changeFolder,
                              icon: const Icon(Icons.swap_horiz, size: 16),
                              label: Text(
                                _changingFolder ? '更改中…' : '更改存储文件夹',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_folderError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _folderError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _SectionLabel('默认展示方式'),
                      const SizedBox(height: 8),
                      if (_loadingPref)
                        const SizedBox(
                          height: 40,
                          child: Center(
                            child: SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<DisplayMethod>(
                            segments: const [
                              ButtonSegment(
                                value: DisplayMethod.inbox,
                                label: Text('应用内查看'),
                                icon: Icon(Icons.visibility_outlined, size: 16),
                              ),
                              ButtonSegment(
                                value: DisplayMethod.system,
                                label: Text('系统默认'),
                                icon: Icon(Icons.description_outlined,
                                    size: 16),
                              ),
                              ButtonSegment(
                                value: DisplayMethod.obsidian,
                                label: Text('Obsidian'),
                                icon: Icon(Icons.hub_outlined, size: 16),
                              ),
                            ],
                            selected: {_method},
                            onSelectionChanged: (s) => _selectMethod(s.first),
                          ),
                        ),
                      const SizedBox(height: 10),
                      const Text(
                        '仅改变查看笔记时使用的应用，不会移动或修改原文件。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A8A96),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _openContent,
                              icon: const Icon(Icons.article_outlined,
                                  size: 16),
                              label: const Text('查看内容'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: widget.onCheckUpdates,
                              icon: const Icon(Icons.system_update_alt,
                                  size: 16),
                              label: const Text('检查更新'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FutureBuilder<AppVersion>(
                            future: _versionFuture,
                            builder: (context, snap) {
                              final v = snap.data;
                              return Text(
                                v == null ? 'INbox' : 'INbox $v',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF8A8A96),
                                ),
                              );
                            },
                          ),
                          TextButton(
                            onPressed: widget.onClose,
                            child: const Text('返回桌宠'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFFB7B7C2),
        letterSpacing: 0.2,
      ),
    );
  }
}
