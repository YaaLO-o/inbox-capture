import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/capture_service.dart';
import 'package:inbox_app/services/clipboard_service.dart';
import 'package:inbox_app/services/storage_service.dart';
import 'package:inbox_app/ui/capture_pill.dart';

class FakeEmptyClipboard implements ClipboardReader {
  @override
  Future<ClipboardContent> read() async => const ClipboardContent();
}

class FakeCaptureService extends CaptureService {
  int calls = 0;
  CaptureResult result;

  FakeCaptureService(this.result)
    : super(clipboard: FakeEmptyClipboard(), storage: StorageService());

  @override
  Future<CaptureResult> captureNow(String vaultPath, {DateTime? now}) async {
    calls += 1;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settingsChannel = MethodChannel('com.inbox.app/settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(settingsChannel, null);
  });

  Future<void> pumpPill(
    WidgetTester tester, {
    required FakeCaptureService capture,
    VoidCallback? onChangeVault,
  }) async {
    await tester.pumpWidget(
      CapturePill(
        vaultPath: '/unused',
        capture: capture,
        onChangeVault: onChangeVault ?? () {},
      ),
    );
    final atlasFuture = tester
        .widget<FutureBuilder<ui.Image>>(find.byType(FutureBuilder<ui.Image>))
        .future!;
    await tester.runAsync(() => atlasFuture);
    await tester.pump();
  }

  testWidgets('显示关闭宝箱且不显示旧控件', (tester) async {
    final capture = FakeCaptureService(
      const CaptureResult(CaptureStatus.saved),
    );
    await pumpPill(tester, capture: capture);

    expect(find.bySemanticsLabel('保存到 INbox'), findsOneWidget);
    expect(find.text('收'), findsNothing);
    expect(find.text('•••'), findsNothing);
    expect(find.text('点击保存'), findsNothing);
  });

  testWidgets('点击箱体只执行一次 Capture', (tester) async {
    final capture = FakeCaptureService(
      const CaptureResult(CaptureStatus.saved),
    );
    await pumpPill(tester, capture: capture);

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    expect(capture.calls, 0);
    await tester.pump();

    expect(capture.calls, 1);
  });

  testWidgets('悬停退出按钮调用原有 quit 且不执行 Capture', (tester) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(settingsChannel, (call) async {
      calls.add(call);
      return null;
    });
    final capture = FakeCaptureService(
      const CaptureResult(CaptureStatus.saved),
    );
    await pumpPill(tester, capture: capture);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    addTearDown(mouse.removePointer);

    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('pet-visible-region'))),
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('退出 INbox'));
    await tester.pump();

    expect(calls.map((call) => call.method), ['quit']);
    expect(capture.calls, 0);
  });

  testWidgets('拖动只通过共享设置通道移动原生窗口', (tester) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(settingsChannel, (call) async {
      calls.add(call);
      return null;
    });
    final capture = FakeCaptureService(
      const CaptureResult(CaptureStatus.saved),
    );
    await pumpPill(tester, capture: capture);

    await tester.drag(
      find.byKey(const Key('pet-drag-handle')),
      const Offset(12, 7),
    );
    await tester.pump();

    expect(calls, isNotEmpty);
    expect(calls.every((call) => call.method == 'moveWindowBy'), isTrue);
    expect(capture.calls, 0);
  });

  testWidgets('右键显示 Vault 和退出菜单且不执行 Capture', (tester) async {
    final capture = FakeCaptureService(
      const CaptureResult(CaptureStatus.saved),
    );
    await pumpPill(tester, capture: capture);

    final center = tester.getCenter(find.bySemanticsLabel('保存到 INbox'));
    final gesture = await tester.startGesture(
      center,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('重新选择 Vault'), findsOneWidget);
    expect(find.text('退出'), findsOneWidget);
    expect(capture.calls, 0);
  });

  testWidgets('重新选择 Vault 菜单调用 onChangeVault', (tester) async {
    var changes = 0;
    final capture = FakeCaptureService(
      const CaptureResult(CaptureStatus.saved),
    );
    await pumpPill(tester, capture: capture, onChangeVault: () => changes += 1);
    final center = tester.getCenter(find.bySemanticsLabel('保存到 INbox'));
    final gesture = await tester.startGesture(
      center,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新选择 Vault'));
    await tester.pumpAndSettle();

    expect(changes, 1);
  });

  testWidgets('退出菜单调用原有 quit 方法', (tester) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(settingsChannel, (call) async {
      calls.add(call);
      return null;
    });
    final capture = FakeCaptureService(
      const CaptureResult(CaptureStatus.saved),
    );
    await pumpPill(tester, capture: capture);
    final center = tester.getCenter(find.bySemanticsLabel('保存到 INbox'));
    final gesture = await tester.startGesture(
      center,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();

    expect(calls.map((call) => call.method), contains('quit'));
  });
}
