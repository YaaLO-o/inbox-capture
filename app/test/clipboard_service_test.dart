import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/clipboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.inbox.app/clipboard');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('平台同时返回文件和 bitmap 时统一为文件优先', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readClipboard');
      return <String, Object>{
        'text': '图片说明',
        'files': <String>['/tmp/source.png'],
        'imageBytes': Uint8List.fromList([1, 2, 3]),
        'imageExtension': 'png',
        'imageMimeType': 'image/png',
      };
    });

    final content = await ClipboardService().read();

    expect(content.text, '图片说明');
    expect(content.files, ['/tmp/source.png']);
    expect(content.imageBytes, isNull);
    expect(content.imageMimeType, isNull);
  });
}
