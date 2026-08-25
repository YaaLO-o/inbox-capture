import 'package:flutter/material.dart';

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

class _AndroidSettingsViewState extends State<AndroidSettingsView> {
  VaultDescriptor? _vault;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVault();
  }

  Future<void> _loadVault() async {
    final vault = await widget.settings.getVault();
    if (!mounted) return;
    setState(() {
      _vault = vault;
      _loading = false;
    });
  }

  Future<void> _pickVault() async {
    final vault = await widget.settings.pickVault();
    if (!mounted || vault == null) return;
    setState(() {
      _vault = vault;
    });
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
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Vault',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
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
                    const Text('将在后续步骤中配置'),
                    const SizedBox(height: 32),
                    Text('权限', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      _vault?.accessible == true
                          ? 'Vault 可读写'
                          : '需要 Vault 读写权限',
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
