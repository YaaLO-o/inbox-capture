import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/capture_service.dart';
import 'package:inbox_app/ui/pet/pixel_chest_pet.dart';
import 'package:inbox_app/ui/pet/pixel_chest_sprite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPet(
    WidgetTester tester, {
    required Future<CaptureResult> Function() onCapture,
    bool disableAnimations = false,
    TargetPlatform platform = TargetPlatform.macOS,
    ValueChanged<Offset>? onMove,
    ValueChanged<Offset>? onSecondaryTap,
    VoidCallback? onDragStart,
    VoidCallback? onDragUpdate,
    VoidCallback? onDragEnd,
  }) async {
    final image = (await tester.runAsync(
      () => loadPixelChestAtlas(rootBundle),
    ))!;
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: PixelChestPet(
            atlas: image,
            onCapture: onCapture,
            onMove: onMove ?? (_) {},
            onSecondaryTap: onSecondaryTap ?? (_) {},
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
        ),
      ),
    );
  }

  Future<TestGesture> hoverPet(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('pet-visible-region'))),
    );
    await tester.pump();
    return mouse;
  }

  testWidgets('hovering the pet does not add a quit button', (tester) async {
    await pumpPet(
      tester,
      onCapture: () async => const CaptureResult(CaptureStatus.saved),
    );

    await hoverPet(tester);

    expect(find.bySemanticsLabel('退出 INbox'), findsNothing);
  });

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
    expect(calls, 0);
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('capture callback starts after a capturing frame is committed', (
    tester,
  ) async {
    final completer = Completer<CaptureResult>();
    var calls = 0;
    bool? capturingWasRendered;
    await pumpPet(
      tester,
      onCapture: () {
        calls += 1;
        capturingWasRendered = find
            .byKey(const Key('pet-state-capturing'))
            .evaluate()
            .isNotEmpty;
        return completer.future;
      },
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));

    expect(calls, 0);
    await tester.pump();
    expect(calls, 1);
    expect(capturingWasRendered, isTrue);

    completer.complete(const CaptureResult(CaptureStatus.saved));
    await tester.pump();
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

  testWidgets('Windows feedback opacity transitions are instantaneous', (
    tester,
  ) async {
    await pumpPet(
      tester,
      platform: TargetPlatform.windows,
      onCapture: () async => const CaptureResult(CaptureStatus.empty),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 364));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('剪贴板为空'), findsOneWidget);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
      Duration.zero,
    );
  });

  testWidgets('macOS feedback retains the short opacity transition', (
    tester,
  ) async {
    await pumpPet(
      tester,
      platform: TargetPlatform.macOS,
      onCapture: () async => const CaptureResult(CaptureStatus.empty),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 364));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('剪贴板为空'), findsOneWidget);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
      const Duration(milliseconds: 120),
    );
  });

  testWidgets('macOS feedback fade is complete by 1400ms from first display', (
    tester,
  ) async {
    await pumpPet(
      tester,
      platform: TargetPlatform.macOS,
      onCapture: () async => const CaptureResult(CaptureStatus.empty),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 364));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('剪贴板为空'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1280));
    await tester.pump(const Duration(milliseconds: 119));
    expect(find.text('剪贴板为空'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('剪贴板为空'), findsNothing);
  });

  testWidgets('reduced-motion feedback clears at the 1400ms boundary', (
    tester,
  ) async {
    await pumpPet(
      tester,
      disableAnimations: true,
      onCapture: () async => const CaptureResult(CaptureStatus.empty),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(find.text('剪贴板为空'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1399));
    expect(find.text('剪贴板为空'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('剪贴板为空'), findsNothing);
  });

  testWidgets('dragging the pet body moves without triggering capture', (
    tester,
  ) async {
    var captures = 0;
    final events = <String>[];
    await pumpPet(
      tester,
      onCapture: () async {
        captures += 1;
        return const CaptureResult(CaptureStatus.saved);
      },
      onMove: (_) => events.add('fallback'),
      onDragStart: () => events.add('start'),
      onDragUpdate: () => events.add('update'),
      onDragEnd: () => events.add('end'),
    );

    await tester.drag(
      find.byKey(const Key('pet-visible-region')),
      const Offset(30, 20),
    );
    expect(events.first, 'start');
    expect(events, contains('update'));
    expect(events.last, 'end');
    expect(events, isNot(contains('fallback')));
    expect(captures, 0);
  });

  testWidgets('cancelled drag still emits end exactly once', (tester) async {
    final events = <String>[];
    await pumpPet(
      tester,
      onCapture: () async => const CaptureResult(CaptureStatus.saved),
      onDragStart: () => events.add('start'),
      onDragUpdate: () => events.add('update'),
      onDragEnd: () => events.add('end'),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('pet-visible-region'))),
    );
    await gesture.moveBy(const Offset(30, 20));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();

    expect(events.first, 'start');
    expect(events.where((event) => event == 'end'), hasLength(1));
    expect(events.last, 'end');
  });

  testWidgets('right click reports its global position without capture', (
    tester,
  ) async {
    final image = (await tester.runAsync(
      () => loadPixelChestAtlas(rootBundle),
    ))!;
    var captures = 0;
    Offset? menuPosition;
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        home: PixelChestPet(
          atlas: image,
          onCapture: () async {
            captures += 1;
            return const CaptureResult(CaptureStatus.saved);
          },
          onMove: (_) {},
          onSecondaryTap: (position) => menuPosition = position,
        ),
      ),
    );

    final center = tester.getCenter(find.bySemanticsLabel('保存到 INbox'));
    final gesture = await tester.startGesture(
      center,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    expect(menuPosition, isNotNull);
    expect(captures, 0);
  });

  Future<void> secondaryClick(WidgetTester tester, Offset position) async {
    final gesture = await tester.startGesture(
      position,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
  }

  testWidgets('transparent sprite padding ignores right click', (tester) async {
    var menuCalls = 0;
    await pumpPet(
      tester,
      onCapture: () async => const CaptureResult(CaptureStatus.saved),
      onSecondaryTap: (_) => menuCalls += 1,
    );

    final spriteTopLeft = tester.getTopLeft(find.byType(PixelChestSprite));
    await secondaryClick(tester, spriteTopLeft + const Offset(3, 3));

    expect(menuCalls, 0);
  });

  testWidgets('hidden feedback label ignores right click', (tester) async {
    var menuCalls = 0;
    await pumpPet(
      tester,
      onCapture: () async => const CaptureResult(CaptureStatus.saved),
      onSecondaryTap: (_) => menuCalls += 1,
    );

    await secondaryClick(
      tester,
      tester.getCenter(find.byType(AnimatedOpacity)),
    );

    expect(menuCalls, 0);
  });

  testWidgets('visible drag and body regions accept right click', (
    tester,
  ) async {
    var menuCalls = 0;
    await pumpPet(
      tester,
      onCapture: () async => const CaptureResult(CaptureStatus.saved),
      onSecondaryTap: (_) => menuCalls += 1,
    );
    final spriteTopLeft = tester.getTopLeft(find.byType(PixelChestSprite));

    await secondaryClick(tester, spriteTopLeft + const Offset(48, 42));
    await secondaryClick(tester, spriteTopLeft + const Offset(48, 72));

    expect(menuCalls, 2);
  });

  testWidgets('visible feedback label accepts right click', (tester) async {
    var menuCalls = 0;
    await pumpPet(
      tester,
      platform: TargetPlatform.windows,
      onCapture: () async => const CaptureResult(CaptureStatus.empty),
      onSecondaryTap: (_) => menuCalls += 1,
    );
    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 364));
    await tester.pump(const Duration(milliseconds: 1));

    await secondaryClick(tester, tester.getCenter(find.text('剪贴板为空')));

    expect(menuCalls, 1);
  });

  int currentFrame(WidgetTester tester) =>
      tester.widget<PixelChestSprite>(find.byType(PixelChestSprite)).frameIndex;

  testWidgets('disableAnimations keeps fast success open for 150ms', (
    tester,
  ) async {
    await pumpPet(
      tester,
      disableAnimations: true,
      onCapture: () async => const CaptureResult(CaptureStatus.saved),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump();
    expect(currentFrame(tester), 9);
    expect(find.byKey(const Key('pet-state-capturing')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 149));
    expect(currentFrame(tester), 9);
    expect(find.byKey(const Key('pet-state-capturing')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(currentFrame(tester), 0);
    expect(find.byKey(const Key('pet-state-idle')), findsOneWidget);
  });

  testWidgets(
    'disableAnimations slow result never waits and closes on result',
    (tester) async {
      final completer = Completer<CaptureResult>();
      await pumpPet(
        tester,
        disableAnimations: true,
        onCapture: () => completer.future,
      );

      await tester.tap(find.bySemanticsLabel('保存到 INbox'));
      await tester.pump(const Duration(milliseconds: 160));
      expect(currentFrame(tester), 9);
      expect(find.byKey(const Key('pet-waiting')), findsNothing);

      completer.complete(const CaptureResult(CaptureStatus.saved));
      await tester.pump();
      await tester.pump();
      expect(currentFrame(tester), 0);
      expect(find.byKey(const Key('pet-state-idle')), findsOneWidget);
      expect(find.byKey(const Key('pet-waiting')), findsNothing);
    },
  );

  testWidgets('disableAnimations empty closes with fixed safe text', (
    tester,
  ) async {
    await pumpPet(
      tester,
      disableAnimations: true,
      onCapture: () async => const CaptureResult(
        CaptureStatus.empty,
        message: '/Users/name/private-vault: clipboard empty',
      ),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(currentFrame(tester), 0);
    expect(find.text('剪贴板为空'), findsOneWidget);
    expect(find.textContaining('private-vault'), findsNothing);
  });

  testWidgets('disableAnimations sync throw closes with fixed safe text', (
    tester,
  ) async {
    await pumpPet(
      tester,
      disableAnimations: true,
      onCapture: () {
        throw StateError('/Users/name/private-vault: permission denied');
      },
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(currentFrame(tester), 0);
    expect(find.text('保存失败'), findsOneWidget);
    expect(find.textContaining('private-vault'), findsNothing);
  });

  testWidgets('disableAnimations rejected future closes with fixed safe text', (
    tester,
  ) async {
    await pumpPet(
      tester,
      disableAnimations: true,
      onCapture: () => Future<CaptureResult>.error(
        StateError('/Users/name/private-vault: permission denied'),
      ),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(currentFrame(tester), 0);
    expect(find.text('保存失败'), findsOneWidget);
    expect(find.textContaining('private-vault'), findsNothing);
  });
}
