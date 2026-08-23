import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/capture_service.dart';
import '../services/settings_service.dart';
import 'pet/pixel_chest_pet.dart';
import 'pet/pixel_chest_sprite.dart';
import 'window_surface.dart';

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

  late final Future<ui.Image> _atlasFuture;

  @override
  void initState() {
    super.initState();
    _atlasFuture = loadPixelChestAtlas(rootBundle);
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (menuContext) => Scaffold(
          backgroundColor: captureWindowSurfaceColor(
            Theme.of(context).platform,
          ),
          body: FutureBuilder<ui.Image>(
            future: _atlasFuture,
            builder: (context, snapshot) {
              final atlas = snapshot.data;
              if (atlas == null) {
                return const Center(child: SizedBox.square(dimension: 96));
              }
              return PixelChestPet(
                atlas: atlas,
                onCapture: () => widget.capture.captureNow(widget.vaultPath),
                onMove: (delta) => _settings.moveWindowBy(delta.dx, delta.dy),
                onSecondaryTap: (position) => _showMenu(menuContext, position),
              );
            },
          ),
        ),
      ),
    );
  }
}
