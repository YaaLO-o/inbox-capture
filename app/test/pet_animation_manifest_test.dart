import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/ui/pet/pet_animation_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ByteData> loadAtlasRgba() async {
    final data = await rootBundle.load(PixelChestAtlas.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    codec.dispose();
    return rgba!;
  }

  int pixelOffset(int frameIndex, int x, int y) {
    final frameLeft =
        (frameIndex % PixelChestAtlas.columns) * PixelChestAtlas.cellSize;
    final frameTop =
        (frameIndex ~/ PixelChestAtlas.columns) * PixelChestAtlas.cellSize;
    return ((frameTop + y) * PixelChestAtlas.pixelWidth + frameLeft + x) * 4;
  }

  bool isRgb(ByteData rgba, int frameIndex, int x, int y, int rgb) {
    final offset = pixelOffset(frameIndex, x, y);
    return rgba.getUint8(offset) == (rgb >> 16) & 0xff &&
        rgba.getUint8(offset + 1) == (rgb >> 8) & 0xff &&
        rgba.getUint8(offset + 2) == rgb & 0xff &&
        rgba.getUint8(offset + 3) == 255;
  }

  ({int top, int bottom}) opaqueVerticalBounds(ByteData rgba, int frameIndex) {
    var top = PixelChestAtlas.cellSize;
    var bottom = -1;
    for (var y = 0; y < PixelChestAtlas.cellSize; y += 1) {
      for (var x = 0; x < PixelChestAtlas.cellSize; x += 1) {
        if (rgba.getUint8(pixelOffset(frameIndex, x, y) + 3) == 0) continue;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    return (top: top, bottom: bottom);
  }

  int largestPaperComponent(ByteData rgba, int frameIndex) {
    final remaining = <int>{};
    for (var y = 0; y < PixelChestAtlas.cellSize; y += 1) {
      for (var x = 0; x < PixelChestAtlas.cellSize; x += 1) {
        if (isRgb(rgba, frameIndex, x, y, 0xE9E0CF)) {
          remaining.add(y * PixelChestAtlas.cellSize + x);
        }
      }
    }

    var largest = 0;
    while (remaining.isNotEmpty) {
      final pending = <int>[remaining.first];
      remaining.remove(pending.first);
      var size = 0;
      while (pending.isNotEmpty) {
        final pixel = pending.removeLast();
        size += 1;
        final x = pixel % PixelChestAtlas.cellSize;
        final y = pixel ~/ PixelChestAtlas.cellSize;
        final neighbors = <int>[
          if (x > 0) pixel - 1,
          if (x + 1 < PixelChestAtlas.cellSize) pixel + 1,
          if (y > 0) pixel - PixelChestAtlas.cellSize,
          if (y + 1 < PixelChestAtlas.cellSize)
            pixel + PixelChestAtlas.cellSize,
        ];
        for (final neighbor in neighbors) {
          if (remaining.remove(neighbor)) pending.add(neighbor);
        }
      }
      if (size > largest) largest = size;
    }
    return largest;
  }

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

  test('capture terminal and waiting frames keep the mouth open', () async {
    final rgba = await loadAtlasRgba();
    final resultGatingFrames = <int>[
      PixelChestAtlas.capture.frames.last,
      ...PixelChestAtlas.waiting.frames,
    ];

    for (final frameIndex in resultGatingFrames) {
      final bounds = opaqueVerticalBounds(rgba, frameIndex);
      expect(
        bounds.bottom - bounds.top + 1,
        greaterThanOrEqualTo(25),
        reason: 'frame $frameIndex must retain the tall open-lid silhouette',
      );
      expect(
        largestPaperComponent(rgba, frameIndex),
        lessThanOrEqualTo(4),
        reason: 'frame $frameIndex must not retain the swallowed paper card',
      );
    }
  });

  test('success closes continuously from the waiting posture', () async {
    final rgba = await loadAtlasRgba();
    final successTops = PixelChestAtlas.success.frames
        .map((frame) => opaqueVerticalBounds(rgba, frame).top)
        .toList();
    final waitingTop = opaqueVerticalBounds(
      rgba,
      PixelChestAtlas.waiting.frames.last,
    ).top;
    final idleTop = opaqueVerticalBounds(
      rgba,
      PixelChestAtlas.idle.frames.first,
    ).top;

    expect((waitingTop - successTops.first).abs(), lessThanOrEqualTo(1));
    for (var index = 1; index < successTops.length; index += 1) {
      expect(successTops[index], greaterThanOrEqualTo(successTops[index - 1]));
    }
    expect(successTops.last, idleTop);
  });

  test('empty chew frames contain no paper card', () async {
    final rgba = await loadAtlasRgba();

    for (final frameIndex in PixelChestAtlas.empty.frames) {
      expect(
        largestPaperComponent(rgba, frameIndex),
        lessThanOrEqualTo(4),
        reason: 'frame $frameIndex may contain short teeth but no paper card',
      );
    }
  });

  test('error sequence keeps the paper card stuck through the shake', () async {
    final rgba = await loadAtlasRgba();

    for (final frameIndex in PixelChestAtlas.error.frames) {
      expect(
        largestPaperComponent(rgba, frameIndex),
        greaterThan(4),
        reason: 'frame $frameIndex must keep the stuck card visible',
      );
    }
  });

  test('all animation frames share the production baseline', () async {
    final rgba = await loadAtlasRgba();
    final idleBottom = opaqueVerticalBounds(
      rgba,
      PixelChestAtlas.idle.frames.first,
    ).bottom;

    for (
      var frameIndex = 0;
      frameIndex < PixelChestAtlas.frameCount;
      frameIndex += 1
    ) {
      expect(
        opaqueVerticalBounds(rgba, frameIndex).bottom,
        idleBottom,
        reason: 'frame $frameIndex must stay on the idle baseline',
      );
    }
  });
}
