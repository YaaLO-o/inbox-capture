import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/capture_service.dart';
import 'package:inbox_app/services/clipboard_service.dart';
import 'package:inbox_app/services/storage_service.dart';
import 'package:inbox_app/ui/capture_pill.dart';

class EmptyClipboard implements ClipboardReader {
  @override
  Future<ClipboardContent> read() async => const ClipboardContent();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settingsChannel = MethodChannel('com.inbox.app/settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(settingsChannel, null);
  });

  CapturePill buildPill() => CapturePill(
    vaultPath: '/unused',
    capture: CaptureService(
      clipboard: EmptyClipboard(),
      storage: StorageService(),
    ),
    onChangeVault: () {},
  );

  testWidgets('显示共享的拖动把手、圆形收入口和状态文字', (tester) async {
    await tester.pumpWidget(buildPill());

    expect(find.text('•••'), findsOneWidget);
    expect(find.text('收'), findsOneWidget);
    expect(find.text('点击保存'), findsOneWidget);
  });

  testWidgets('拖动把手通过共享设置通道移动原生窗口', (tester) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(settingsChannel, (call) async {
      calls.add(call);
      return null;
    });
    await tester.pumpWidget(buildPill());

    await tester.drag(find.text('•••'), const Offset(12, 7));
    await tester.pump();

    expect(calls, isNotEmpty);
    expect(calls.every((call) => call.method == 'moveWindowBy'), isTrue);
  });
}
