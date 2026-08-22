import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/capture_service.dart';
import 'package:inbox_app/ui/pet/pet_animation_manifest.dart';
import 'package:inbox_app/ui/pet/pixel_chest_pet.dart';
import 'package:inbox_app/ui/pet/pixel_chest_sprite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPet(
    WidgetTester tester, {
    required Future<CaptureResult> Function() onCapture,
    bool disableAnimations = false,
  }) async {
    final image = (await tester.runAsync(
      () => loadPixelChestAtlas(rootBundle),
    ))!;
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: PixelChestPet(
            atlas: image,
            onCapture: onCapture,
            onMove: (_) {},
            onSecondaryTap: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('fast success still completes the capture intro first', (
    tester,
  ) async {
    await pumpPet(
      tester,
      onCapture: () async => const CaptureResult(CaptureStatus.saved),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump();
    expect(find.byKey(const Key('pet-state-capturing')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('pet-state-capturing')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 64));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const Key('pet-state-success')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 440));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const Key('pet-state-idle')), findsOneWidget);
  });

  testWidgets('slow result enters and leaves the waiting loop', (tester) async {
    final completer = Completer<CaptureResult>();
    await pumpPet(tester, onCapture: () => completer.future);

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const Key('pet-waiting')), findsOneWidget);

    completer.complete(const CaptureResult(CaptureStatus.saved));
    await tester.pump();
    expect(find.byKey(const Key('pet-state-success')), findsOneWidget);
  });

  testWidgets('capturing ignores repeated body clicks', (tester) async {
    final completer = Completer<CaptureResult>();
    var calls = 0;
    await pumpPet(
      tester,
      onCapture: () {
        calls += 1;
        return completer.future;
      },
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    expect(calls, 1);
  });

  testWidgets('empty uses safe text and returns to idle', (tester) async {
    await pumpPet(
      tester,
      onCapture: () async =>
          const CaptureResult(CaptureStatus.empty, message: '剪贴板为空'),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 364));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('剪贴板为空'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 480));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const Key('pet-state-idle')), findsOneWidget);
  });

  testWidgets('error never exposes raw exception text', (tester) async {
    await pumpPet(
      tester,
      onCapture: () async => const CaptureResult(
        CaptureStatus.error,
        message: '/Users/name/private-vault: permission denied',
      ),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 364));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('保存失败'), findsOneWidget);
    expect(find.textContaining('private-vault'), findsNothing);
  });

  testWidgets('thrown capture errors use safe text', (tester) async {
    await pumpPet(
      tester,
      onCapture: () {
        throw StateError('/Users/name/private-vault: permission denied');
      },
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 364));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('保存失败'), findsOneWidget);
    expect(find.textContaining('private-vault'), findsNothing);
  });

  testWidgets('failed capture futures use safe text', (tester) async {
    await pumpPet(
      tester,
      onCapture: () => Future<CaptureResult>.error(
        StateError('/Users/name/private-vault: permission denied'),
      ),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 364));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('保存失败'), findsOneWidget);
    expect(find.textContaining('private-vault'), findsNothing);
  });
}
