import 'dart:io';

import 'package:flutter/material.dart';

import '../util/path_utils.dart';

/// INbox 内置只读查看器：极简展示，不做任何编辑或内容管理。
///
/// 左侧列出最近的每日笔记文件（按日期倒序），右侧用 [SelectableText]
/// 原文展示选中日期的 Markdown 内容。刻意不渲染 Markdown，也不提供编辑，
/// 守住"不做成笔记软件"的边界。
class NoteReaderView extends StatefulWidget {
  final String vaultPath;
  final VoidCallback onBack;

  const NoteReaderView({
    super.key,
    required this.vaultPath,
    required this.onBack,
  });

  @override
  State<NoteReaderView> createState() => _NoteReaderViewState();
}

class _NoteReaderViewState extends State<NoteReaderView> {
  late List<File> _files;
  File? _selected;
  String? _readError;

  @override
  void initState() {
    super.initState();
    _files = _listFiles();
    _selected = _files.isNotEmpty ? _files.first : null;
  }

  List<File> _listFiles() {
    final dir = Directory(VaultPaths.captureDir(widget.vaultPath));
    if (!dir.existsSync()) return const [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files.take(30).toList();
  }

  String? _readSelected() {
    final f = _selected;
    if (f == null) return null;
    try {
      return f.readAsStringSync();
    } catch (e) {
      _readError = e.toString();
      return null;
    }
  }

  String _labelFor(File f) {
    final name = f.uri.pathSegments.last;
    return name.endsWith('.md')
        ? name.substring(0, name.length - 3)
        : name;
  }

  @override
  Widget build(BuildContext context) {
    final content = _readSelected();
    final empty = _files.isEmpty;

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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('返回'),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '查看内容',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2A2A33)),
            Expanded(
              child: empty
                  ? const Center(
                      child: Text(
                        '还没有采集内容',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8A8A96),
                        ),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 160,
                          child: ListView.builder(
                            itemCount: _files.length,
                            itemBuilder: (context, i) {
                              final f = _files[i];
                              final selected = identical(f, _selected);
                              return Material(
                                color: selected
                                    ? const Color(0xFF2F3B39)
                                    : Colors.transparent,
                                child: InkWell(
                                  onTap: () => setState(() => _selected = f),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      _labelFor(f),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFFB7B7C2),
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const VerticalDivider(
                          width: 1,
                          color: Color(0xFF2A2A33),
                        ),
                        Expanded(
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(18),
                              child: content == null
                                  ? Text(
                                      _readError ?? '无法读取该文件',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.redAccent,
                                      ),
                                    )
                                  : SelectableText(
                                      content,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.6,
                                        color: Color(0xFFE6E6EA),
                                        fontFamily: '.AppleSystemUIFont',
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
