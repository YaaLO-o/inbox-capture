import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/capture_service.dart';
import '../services/settings_service.dart';
import 'pet/pet_popup_menu.dart';
import 'pet/pixel_chest_pet.dart';
import 'pet/pixel_chest_sprite.dart';
import 'window_surface.dart';
import 'window_sizes.dart';

/// 两个平台共用的低摩擦悬浮采集入口。
class CapturePill extends StatefulWidget {
  final String vaultPath;
  final CaptureService capture;
  final void Function() onChangeVault;
  final void Function() onCheckUpdates;

  const CapturePill({
    super.key,
    required this.vaultPath,
    required this.capture,
    required this.onChangeVault,
    required this.onCheckUpdates,
  });

  @override
  State<CapturePill> createState() => _CapturePillState();
}

class _CapturePillState extends State<CapturePill> {
  static final SettingsService _settings = SettingsService();

  late final Future<ui.Image> _atlasFuture;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _atlasFuture = loadPixelChestAtlas(rootBundle);
  }

  void _toggleMenu() {
    setState(() => _menuOpen = !_menuOpen);
    _syncWindowSize();
  }

  void _closeMenu() {
    if (!_menuOpen) return;
    setState(() => _menuOpen = false);
    _syncWindowSize();
  }

  void _syncWindowSize() {
    final h = _menuOpen
        ? WindowSizes.pillHeight + PetPopupMenu.menuHeight + _menuGap
        : WindowSizes.pillHeight;
    _settings.setWindowSize(WindowSizes.pillWidth, h);
  }

  static const double _menuGap = 4;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: Material(
        color: captureWindowSurfaceColor(defaultTargetPlatform),
        child: FutureBuilder<ui.Image>(
          future: _atlasFuture,
          builder: (context, snapshot) {
            final atlas = snapshot.data;
            if (atlas == null) {
              return const Center(child: SizedBox.square(dimension: 96));
            }
            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // 桌宠
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PixelChestPet(
                      atlas: atlas,
                      onCapture: () =>
                          widget.capture.captureNow(widget.vaultPath),
                      onMove: defaultTargetPlatform == TargetPlatform.windows
                          ? (delta) =>
                                _settings.moveWindowBy(delta.dx, delta.dy)
                          : (_) {},
                      onSecondaryTap: (_) => _toggleMenu(),
                      onDragStart: defaultTargetPlatform == TargetPlatform.macOS
                          ? _settings.beginWindowDrag
                          : null,
                      onDragUpdate:
                          defaultTargetPlatform == TargetPlatform.macOS
                          ? _settings.updateWindowDrag
                          : null,
                      onDragEnd: defaultTargetPlatform == TargetPlatform.macOS
                          ? _settings.endWindowDrag
                          : null,
                    ),
                  ],
                ),
                // 透明遮罩：菜单打开时点击外部关闭
                if (_menuOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _closeMenu,
                      onSecondaryTap: _closeMenu,
                      onPanStart: (_) => _closeMenu(),
                    ),
                  ),
                // 菜单（在遮罩之上，不被拦截）
                if (_menuOpen)
                  Positioned(
                    top: WindowSizes.pillHeight + _menuGap,
                    left: 0,
                    child: PetPopupMenu(
                      onSelectVault: () {
                        _closeMenu();
                        widget.onChangeVault();
                      },
                      onCheckUpdates: () {
                        _closeMenu();
                        widget.onCheckUpdates();
                      },
                      onQuit: () {
                        _closeMenu();
                        _settings.quit();
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
