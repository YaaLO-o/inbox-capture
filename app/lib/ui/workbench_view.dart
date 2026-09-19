import 'dart:io';

import 'package:flutter/material.dart';

import '../services/display_service.dart';
import '../services/settings_service.dart';
import '../services/vault_storage.dart';
import '../util/path_utils.dart';
import 'control_center_view.dart';
import 'workbench_sidebar.dart';

const _surface = Color(0xFF171A1E);
const _sidebar = Color(0xFF20252A);
const _border = Color(0xFF343A40);
const _muted = Color(0xFF9AA5AD);
const _accent = Color(0xFF69D6BD);

/// Desktop workspace for browsing captured daily notes and app settings.
class WorkbenchView extends StatefulWidget {
  final String vaultPath;
  final SettingsService settings;
  final VaultStorage storage;
  final DisplayService display;
  final VoidCallback onCheckUpdates;
  final VoidCallback onClose;
  final ValueChanged<String> onVaultPathChanged;

  const WorkbenchView({
    super.key,
    required this.vaultPath,
    required this.settings,
    required this.storage,
    required this.display,
    required this.onCheckUpdates,
    required this.onClose,
    required this.onVaultPathChanged,
  });

  @override
  State<WorkbenchView> createState() => _WorkbenchViewState();
}

class _WorkbenchViewState extends State<WorkbenchView> {
  late List<File> _files;
  File? _selected;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _files = _listFiles(widget.vaultPath);
    _selected = _files.isEmpty ? null : _files.first;
  }

  List<File> _listFiles(String vaultPath) {
    final dir = Directory(VaultPaths.captureDir(vaultPath));
    if (!dir.existsSync()) return const [];
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.md'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    return files.take(30).toList();
  }

  String _labelFor(File file) {
    final name = file.uri.pathSegments.last;
    return name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
  }

  Widget _buildSidebar() {
    return Material(
      color: _sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: _accent, size: 20),
                SizedBox(width: 10),
                Text(
                  'INbox',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Text(
              '最近采集',
              style: TextStyle(fontSize: 11, color: _muted, letterSpacing: 1.2),
            ),
          ),
          Expanded(
            child: _files.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      '暂无每日笔记',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      final selected =
                          !_showSettings && file.path == _selected?.path;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Material(
                          color: selected
                              ? const Color(0xFF2D4440)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () => setState(() {
                              _selected = file;
                              _showSettings = false;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.article_outlined,
                                    size: 16,
                                    color: selected ? _accent : _muted,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _labelFor(file),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFFCED5D9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  selected: _showSettings,
                  selectedTileColor: const Color(0xFF2D4440),
                  leading: const Icon(Icons.settings_outlined, size: 19),
                  title: const Text('设置'),
                  onTap: () => setState(() => _showSettings = true),
                ),
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  leading: const Icon(Icons.pets_outlined, size: 19),
                  title: const Text('返回桌宠'),
                  onTap: widget.onClose,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteBody() {
    final file = _selected;
    if (file == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 36, color: _muted),
            SizedBox(height: 12),
            Text('还没有采集内容', style: TextStyle(color: _muted)),
          ],
        ),
      );
    }

    String content;
    try {
      content = file.readAsStringSync();
    } catch (error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '无法读取该文件：$error',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 30, 32, 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SelectableText(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.75,
              color: Color(0xFFE2E8EB),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMain(BuildContext context) {
    final scope = WorkbenchSidebarScope.of(context);
    return Column(
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              IconButton(
                key: const Key('sidebar-toggle'),
                tooltip: scope.open ? '收起侧栏' : '展开侧栏',
                onPressed: scope.toggle,
                icon: const Icon(Icons.menu_open_rounded, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _showSettings
                      ? '设置'
                      : (_selected == null ? '查看内容' : _labelFor(_selected!)),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_showSettings)
                const Text('只读', style: TextStyle(fontSize: 11, color: _muted)),
            ],
          ),
        ),
        Expanded(
          child: _showSettings
              ? ControlCenterView(
                  vaultPath: widget.vaultPath,
                  settings: widget.settings,
                  storage: widget.storage,
                  display: widget.display,
                  onVaultPathChanged: widget.onVaultPathChanged,
                  onCheckUpdates: widget.onCheckUpdates,
                  onOpenContent: () => setState(() => _showSettings = false),
                  onClose: widget.onClose,
                )
              : _buildNoteBody(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: _accent,
        scaffoldBackgroundColor: _surface,
        fontFamily: '.AppleSystemUIFont',
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _surface,
                border: Border.all(color: _border),
              ),
              child: WorkbenchSidebar(
                sidebar: _buildSidebar(),
                child: Builder(builder: _buildMain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
