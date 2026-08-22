import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/ui/pet/pet_animation_manifest.dart';
import 'package:inbox_app/ui/pet/pixel_chest_sprite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frame source rectangles follow the 8-column atlas grid', () {
    expect(pixelChestSourceRect(0), const Rect.fromLTWH(0, 0, 32, 32));
    expect(pixelChestSourceRect(7), const Rect.fromLTWH(224, 0, 32, 32));
    expect(pixelChestSourceRect(8), const Rect.fromLTWH(0, 32, 32, 32));
    expect(pixelChestSourceRect(21), const Rect.fromLTWH(160, 64, 32, 32));
  });

  testWidgets('idle sprite paints at exactly 96 logical pixels', (
    tester,
  ) async {
    final image = (await tester.runAsync(
      () => loadPixelChestAtlas(rootBundle),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: const Key('idle-boundary'),
            child: PixelChestSprite(image: image, frameIndex: 0),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(PixelChestSprite)),
      const Size.square(PixelChestAtlas.displaySize),
    );
    await expectLater(
      find.byKey(const Key('idle-boundary')),
      matchesGoldenFile('goldens/pixel_chest_idle.png'),
    );
  });

  testWidgets('capture-open sprite matches its approved frame', (tester) async {
    final image = (await tester.runAsync(
      () => loadPixelChestAtlas(rootBundle),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: const Key('capture-boundary'),
            child: PixelChestSprite(image: image, frameIndex: 6),
          ),
        ),
      ),
    );

    await expectLater(
      find.byKey(const Key('capture-boundary')),
      matchesGoldenFile('goldens/pixel_chest_capture_open.png'),
    );
  });
}
