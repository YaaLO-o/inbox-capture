import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/ui/pet/pet_animation_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pixel chest atlas uses the fixed 8 by 3 cell layout', () async {
    final data = await rootBundle.load(PixelChestAtlas.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();

    expect(frame.image.width, PixelChestAtlas.pixelWidth);
    expect(frame.image.height, PixelChestAtlas.pixelHeight);
    expect(PixelChestAtlas.pixelWidth, 256);
    expect(PixelChestAtlas.pixelHeight, 96);
    expect(PixelChestAtlas.frameCount, 22);
  });

  test('atlas uses binary alpha and the approved opaque palette', () async {
    final data = await rootBundle.load(PixelChestAtlas.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = bytes!.buffer.asUint8List();
    final seenOpaque = <int>{};

    for (var i = 0; i < rgba.length; i += 4) {
      final alpha = rgba[i + 3];
      expect(<int>{0, 255}, contains(alpha));
      if (alpha == 0) continue;
      seenOpaque.add((rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2]);
    }

    expect(seenOpaque.difference(PixelChestAtlas.allowedOpaqueRgb), isEmpty);
  });

  test('animation sequences match the approved durations and frame ranges', () {
    expect(PixelChestAtlas.capture.frames, [3, 4, 5, 6, 7, 8, 9]);
    expect(
      PixelChestAtlas.capture.totalDuration,
      const Duration(milliseconds: 364),
    );
    expect(PixelChestAtlas.waiting.frames, [10, 11]);
    expect(PixelChestAtlas.waiting.loop, isTrue);
    expect(PixelChestAtlas.success.frames, [12, 13, 14, 15]);
    expect(
      PixelChestAtlas.success.totalDuration,
      const Duration(milliseconds: 440),
    );
    expect(
      PixelChestAtlas.error.totalDuration,
      const Duration(milliseconds: 480),
    );
    expect(
      PixelChestAtlas.empty.totalDuration,
      const Duration(milliseconds: 480),
    );
  });
}
