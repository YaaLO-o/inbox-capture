import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/models/capture.dart';
import 'package:inbox_app/services/capture_service.dart';
import 'package:inbox_app/services/clipboard_service.dart';
import 'package:inbox_app/services/storage_service.dart';
import 'package:inbox_app/util/id_gen.dart';
import 'package:inbox_app/util/path_utils.dart';

class FakeClipboard implements ClipboardReader {
  ClipboardContent content;
  FakeClipboard(this.content);

  @override
  Future<ClipboardContent> read() async => content;
}

void main() {
  late Directory tmp;
  late StorageService storage;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('inbox_test_');
    storage = StorageService();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  String readInbox(String vault, DateTime d) =>
      File(VaultPaths.dailyInboxFile(vault, d)).readAsStringSync();

  test('两个桌面平台共享 Universal Capture 路径协议', () {
    final now = DateTime(2026, 8, 21, 10, 32, 15);
    final sep = Platform.pathSeparator;

    expect(
      VaultPaths.dailyInboxFile(tmp.path, now),
      '${tmp.path}${sep}Universal Capture${sep}2026-08-21.md',
    );
    expect(
      VaultPaths.attachmentsDir(tmp.path),
      '${tmp.path}${sep}Universal Capture${sep}attachments',
    );
    expect(VaultPaths.embedRef('image.png'), 'attachments/image.png');
  });

  test('平台适配器输入相同 Capture 时生成完全相同的 Markdown', () {
    final now = DateTime(2026, 8, 21, 10, 32, 15);
    final macVault = Directory('${tmp.path}/macos')..createSync();
    final windowsVault = Directory('${tmp.path}/windows')..createSync();
    final sharedCapture = Capture(
      id: '20260821-103215-a82f',
      createdAt: now,
      text: '同一条共享 Capture',
      attachments: const [
        Attachment(
          id: '20260821-103215-a82f',
          fileName: '20260821-103215-a82f.png',
          originalExtension: 'png',
          mimeType: 'image/png',
        ),
      ],
    );
    storage.appendCapture(macVault.path, sharedCapture);
    storage.appendCapture(windowsVault.path, sharedCapture);

    expect(readInbox(macVault.path, now), readInbox(windowsVault.path, now));
  });

  test('generateCaptureId 格式正确且按时间变化', () {
    final a = generateCaptureId(DateTime(2026, 8, 21, 10, 32, 15));
    expect(a, startsWith('20260821-103215-'));
    expect(a.length, 8 + 1 + 6 + 1 + 4); // YYYYMMDD-HHMMSS-XXXX
  });

  test('文字 Capture：新建文件、写标题、追加内容、含独立 ID', () async {
    final now = DateTime(2026, 8, 21, 10, 32, 15);
    final svc = CaptureService(
      clipboard: FakeClipboard(const ClipboardContent(text: '  一段笔记内容  ')),
      storage: storage,
    );

    final r = await svc.captureNow(tmp.path, now: now);
    expect(r.isSaved, isTrue);
    expect(r.captureId, startsWith('20260821-103215-'));

    final md = readInbox(tmp.path, now);
    expect(md.startsWith('# 2026-08-21\n'), isTrue);
    expect(md, contains('## 10:32:15'));
    expect(md, contains('<!-- capture:id=${r.captureId} -->'));
    expect(md, contains('一段笔记内容')); // trim 生效
    expect(md, endsWith('---\n\n'));
  });

  test('连续 10 条：全部追加、不覆盖、顺序正确、ID 唯一', () async {
    final base = DateTime(2026, 8, 21, 9, 0, 0);
    final svc = CaptureService(
      clipboard: FakeClipboard(const ClipboardContent(text: 'x')),
      storage: storage,
    );
    final ids = <String>{};
    for (var i = 0; i < 10; i++) {
      final now = base.add(Duration(seconds: i + 1));
      (svc.clipboard as FakeClipboard).content = ClipboardContent(
        text: '笔记 #$i',
      );
      final r = await svc.captureNow(tmp.path, now: now);
      expect(r.isSaved, isTrue, reason: '第 $i 条应保存成功');
      ids.add(r.captureId!);
    }
    expect(ids.length, 10);

    final md = readInbox(tmp.path, base);
    // 标题只出现一次（不覆盖、不重复写标题）。
    expect('# 2026-08-21\n'.allMatches(md).length, 1);
    // 边界数量等于条目数。
    expect('---\n'.allMatches(md).length, 10);
    // 顺序正确。
    for (var i = 0; i < 10; i++) {
      expect(md.contains('笔记 #$i'), isTrue);
    }
    expect(md.indexOf('笔记 #0'), lessThan(md.indexOf('笔记 #9')));
  });

  test('图片 Capture：写入 attachments 并在 Markdown 嵌入引用', () async {
    final now = DateTime(2026, 8, 21, 14, 20, 31);
    final pngBytes = Uint8List.fromList(List.generate(64, (i) => i % 256));
    final svc = CaptureService(
      clipboard: FakeClipboard(
        ClipboardContent(
          imageBytes: pngBytes,
          imageExtension: 'png',
          imageMimeType: 'image/png',
        ),
      ),
      storage: storage,
    );

    final r = await svc.captureNow(tmp.path, now: now);
    expect(r.isSaved, isTrue);

    final attDir = Directory(VaultPaths.attachmentsDir(tmp.path));
    final files = attDir.listSync().whereType<File>().toList();
    expect(files.length, 1);
    expect(files.single.path.endsWith('.png'), isTrue);
    expect(files.single.readAsBytesSync(), pngBytes);

    final md = readInbox(tmp.path, now);
    final fileName = files.single.uri.pathSegments.last;
    expect(md, contains('![[attachments/$fileName]]'));
  });

  test('Finder 复制的本地文件：复制进 attachments 并嵌入', () async {
    final now = DateTime(2026, 8, 21, 18, 4, 12);
    final src = File('${tmp.path}/source.mp4')
      ..writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));
    final svc = CaptureService(
      clipboard: FakeClipboard(ClipboardContent(files: [src.path])),
      storage: storage,
    );

    final r = await svc.captureNow(tmp.path, now: now);
    expect(r.isSaved, isTrue);

    final md = readInbox(tmp.path, now);
    expect(
      md.contains(
        RegExp(r'!\[\[attachments/20260821-180412-[0-9a-f]{4}\.mp4\]\]'),
      ),
      isTrue,
    );
    // 源文件仍在（是复制，不是移动）。
    expect(src.existsSync(), isTrue);
  });

  test('空剪贴板：不创建文件，返回 empty', () async {
    final now = DateTime(2026, 8, 21, 11, 0, 0);
    final svc = CaptureService(
      clipboard: FakeClipboard(const ClipboardContent()),
      storage: storage,
    );
    final r = await svc.captureNow(tmp.path, now: now);
    expect(r.status, CaptureStatus.empty);
    expect(
      File(VaultPaths.dailyInboxFile(tmp.path, now)).existsSync(),
      isFalse,
    );
  });

  test('文字+图片混合：两者都写入同一条 Capture', () async {
    final now = DateTime(2026, 8, 21, 16, 0, 0);
    final svc = CaptureService(
      clipboard: FakeClipboard(
        ClipboardContent(
          text: '这本书以后看看',
          imageBytes: Uint8List.fromList([9, 8, 7]),
          imageExtension: 'jpg',
        ),
      ),
      storage: storage,
    );
    final r = await svc.captureNow(tmp.path, now: now);
    expect(r.isSaved, isTrue);
    final md = readInbox(tmp.path, now);
    expect(md, contains('这本书以后看看'));
    expect(
      md.contains(RegExp(r'!\[\[attachments/[0-9\-a-f]+\.jpg\]\]')),
      isTrue,
    );
  });
}
