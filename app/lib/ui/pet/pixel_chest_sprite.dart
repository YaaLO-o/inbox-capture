import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'pet_animation_manifest.dart';

Future<ui.Image> loadPixelChestAtlas(AssetBundle bundle) async {
  final data = await bundle.load(PixelChestAtlas.assetPath);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Rect pixelChestSourceRect(int frameIndex) {
  assert(frameIndex >= 0 && frameIndex < PixelChestAtlas.frameCount);
  final column = frameIndex % PixelChestAtlas.columns;
  final row = frameIndex ~/ PixelChestAtlas.columns;
  return Rect.fromLTWH(
    column * PixelChestAtlas.cellSize.toDouble(),
    row * PixelChestAtlas.cellSize.toDouble(),
    PixelChestAtlas.cellSize.toDouble(),
    PixelChestAtlas.cellSize.toDouble(),
  );
}

class PixelChestSprite extends StatelessWidget {
  final ui.Image image;
  final int frameIndex;

  const PixelChestSprite({
    super.key,
    required this.image,
    required this.frameIndex,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: PixelChestAtlas.displaySize,
      child: CustomPaint(
        painter: _PixelChestPainter(image: image, frameIndex: frameIndex),
      ),
    );
  }
}

class _PixelChestPainter extends CustomPainter {
  final ui.Image image;
  final int frameIndex;

  const _PixelChestPainter({required this.image, required this.frameIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    canvas.drawImageRect(
      image,
      pixelChestSourceRect(frameIndex),
      Offset.zero & size,
      paint,
    );
  }

  @override
  bool shouldRepaint(_PixelChestPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.frameIndex != frameIndex;
}
