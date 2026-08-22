import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import 'window_sizes.dart';

/// 首次启动：让用户选择 Obsidian Vault（见《方案》第十二节）。
class OnboardingView extends StatefulWidget {
  final SettingsService settings;
  final void Function(String vaultPath) onVaultSelected;

  const OnboardingView({
    super.key,
    required this.settings,
    required this.onVaultSelected,
  });

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  String? _pickedPath;
  bool _picking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 放大窗口以容纳引导内容。
    widget.settings.setWindowSize(
      WindowSizes.onboardingWidth,
      WindowSizes.onboardingHeight,
    );
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final path = await widget.settings.pickFolder();
      if (!mounted) return;
      if (path == null) {
        setState(() => _picking = false);
        return;
      }
      setState(() {
        _pickedPath = path;
        _picking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _picking = false;
      });
    }
  }

  Future<void> _confirm() async {
    final path = _pickedPath;
    if (path == null) return;
    await widget.settings.setVaultPath(path);
    if (!mounted) return;
    widget.onVaultSelected(path);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C5CFF),
        fontFamily: '.AppleSystemUIFont',
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF1E1E24),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择 Obsidian Vault',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '采集内容将写入该 Vault 下的 Universal Capture 目录，附件保存在其中的 attachments 子目录。',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFB7B7C2),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: _picking ? null : _pick,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A33),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3A3A45)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.folder_open_outlined,
                        size: 18,
                        color: Color(0xFFB7B7C2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _pickedPath ?? '点击选择文件夹…',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _pickedPath == null
                                ? const Color(0xFF8A8A96)
                                : Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: FilledButton(
                  onPressed: _pickedPath == null || _picking ? null : _confirm,
                  child: Text(_picking ? '选择中…' : '开始使用'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
