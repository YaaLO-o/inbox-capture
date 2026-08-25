import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/models/capture.dart';
import 'package:inbox_app/services/capture_service.dart';
import 'package:inbox_app/services/clipboard_service.dart';
import 'package:inbox_app/services/desktop_file_vault_storage.dart';
import 'package:inbox_app/services/markdown_formatter.dart';
import 'package:inbox_app/services/vault_storage.dart';
import 'package:inbox_app/util/id_gen.dart';
import 'package:inbox_app/util/path_utils.dart';

class FakeClipboard implements ClipboardReader {
  ClipboardContent content;
  FakeClipboard(this.content);

  @override
  Future<ClipboardContent> read() async => content;
}

class RecordingVaultStorage implements VaultStorage {
  String? appendedMarkdown;

  @override
  Future<void> appendMarkdown(
    String vaultId,
    DateTime date,
    String markdown,
  ) async {
    appendedMarkdown = markdown;
  }

  @override
  Future<void> deleteAttachment(String vaultId, String fileName) async {}

  @override
  Future<void> ensureLayout(String vaultId) async {}

  @override
  Future<void> importAttachment(
    String vaultId,
    AttachmentSource source,
    String fileName,
  ) async {}
}

void main() {
  late Directory tmp;
  late DesktopFileVaultStorage storage;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('inbox_test_');
    storage = DesktopFileVaultStorage();
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

  test('平台适配器输入相同 Capture 时生成完全相同的 Markdown', () async {
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
    final markdown = const MarkdownFormatter().format(sharedCapture);
    final date = DateTime(now.year, now.month, now.day);
    await storage.ensureLayout(macVault.path);
    await storage.appendMarkdown(macVault.path, date, markdown);
    await storage.ensureLayout(windowsVault.path);
    await storage.appendMarkdown(windowsVault.path, date, markdown);

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
    expect(
      md.startsWith('## 10:32\n\n<!-- capture:id=${r.captureId} -->\n'),
      isTrue,
    );
    expect(md, isNot(startsWith('# 2026-08-21\n')));
    expect(md, isNot(contains('## 10:32:15')));
    expect(md, contains('<!-- capture:id=${r.captureId} -->'));
    expect(md, contains('一段笔记内容')); // trim 生效
    expect(md, endsWith('---\n\n'));
  });

  test(
    'CaptureService awaits storage and appends the exact formatted Markdown',
    () async {
      final storage = RecordingVaultStorage();
      final svc = CaptureService(
        clipboard: FakeClipboard(const ClipboardContent(text: '  一段笔记内容  ')),
        storage: storage,
      );

      final result = await svc.captureNow(
        'vault-id',
        now: DateTime(2026, 8, 24, 9, 30, 12),
      );

      expect(result.isSaved, isTrue);
      expect(storage.appendedMarkdown, '''## 09:30

<!-- capture:id=${result.captureId} -->

一段笔记内容

---

''');
    },
  );

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
    // 日期只由文件名表达，正文不重复日期标题。
    expect('# 2026-08-21\n'.allMatches(md), isEmpty);
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

  test('Finder 文件按类型落盘，并以普通链接保留安全显示名', () async {
    final base = DateTime(2026, 8, 21, 18, 4, 12);
    final sources =
        <({String name, String extension, String displayName, bool isImage})>[
          (
            name: '合同]|终版.pdf',
            extension: 'pdf',
            displayName: '合同终版.pdf',
            isImage: false,
          ),
          (
            name: '演示.mp4',
            extension: 'mp4',
            displayName: '演示.mp4',
            isImage: false,
          ),
          (
            name: '产品演示.MOV',
            extension: 'mov',
            displayName: '产品演示.MOV',
            isImage: false,
          ),
          (
            name: '报价单.docx',
            extension: 'docx',
            displayName: '报价单.docx',
            isImage: false,
          ),
          (
            name: '资料包.zip',
            extension: 'zip',
            displayName: '资料包.zip',
            isImage: false,
          ),
          (
            name: '说明.unknown',
            extension: 'unknown',
            displayName: '说明.unknown',
            isImage: false,
          ),
          (
            name: '图片.PNG',
            extension: 'png',
            displayName: '图片.PNG',
            isImage: true,
          ),
          (
            name: '矢量图.svg',
            extension: 'svg',
            displayName: '矢量图.svg',
            isImage: true,
          ),
          (
            name: '相机原图.heic',
            extension: 'heic',
            displayName: '相机原图.heic',
            isImage: false,
          ),
        ];
    final svc = CaptureService(
      clipboard: FakeClipboard(const ClipboardContent()),
      storage: storage,
    );

    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      final src = File('${tmp.path}/${source.name}')
        ..writeAsBytesSync(Uint8List.fromList([i, i + 1]));
      final now = base.add(Duration(seconds: i));
      (svc.clipboard as FakeClipboard).content = ClipboardContent(
        text: '附件 ${i + 1}',
        files: [src.path],
      );

      final result = await svc.captureNow(tmp.path, now: now);

      expect(result.isSaved, isTrue);
      final fileName = '${result.captureId}.${source.extension}';
      final copied = File('${VaultPaths.attachmentsDir(tmp.path)}/$fileName');
      expect(copied.readAsBytesSync(), [i, i + 1]);

      final md = readInbox(tmp.path, now);
      final entry = source.isImage
          ? '![[attachments/$fileName]]'
          : '[[attachments/$fileName|${source.displayName}]]';
      expect(md, contains(entry));
      if (!source.isImage) {
        expect(md, isNot(contains('![[attachments/$fileName]]')));
      }
      expect(
        md.indexOf('## ${VaultPaths.timeStamp(now)}'),
        lessThan(md.indexOf('<!-- capture:id=${result.captureId} -->')),
      );
      expect(
        md.indexOf('<!-- capture:id=${result.captureId} -->'),
        lessThan(md.indexOf('附件 ${i + 1}')),
      );
      expect(md.indexOf('附件 ${i + 1}'), lessThan(md.indexOf(entry)));
      expect(md.indexOf(entry), lessThan(md.indexOf('---', md.indexOf(entry))));
      expect(src.existsSync(), isTrue); // 复制，不移动。
    }
  });

  test('危险扩展名和换行显示名不会破坏 Wikilink 或 Capture 边界', () async {
    final now = DateTime(2026, 8, 21, 18, 5, 30);
    final src = File('${tmp.path}/报告\n---\n终版.bad#draft')
      ..writeAsBytesSync([1, 2, 3]);
    final svc = CaptureService(
      clipboard: FakeClipboard(ClipboardContent(files: [src.path])),
      storage: storage,
    );

    final result = await svc.captureNow(tmp.path, now: now);

    expect(result.isSaved, isTrue);
    final storedName = result.captureId!;
    expect(
      File('${VaultPaths.attachmentsDir(tmp.path)}/$storedName').existsSync(),
      isTrue,
    );
    final md = readInbox(tmp.path, now);
    expect(md, contains('[[attachments/$storedName|报告 --- 终版.baddraft]]'));
    expect(md, isNot(contains('attachments/$storedName.bad#draft')));
    expect('---\n'.allMatches(md), hasLength(1));
  });

  test('本地文件优先于同一剪贴板对象的重复图片 bytes', () async {
    final now = DateTime(2026, 8, 21, 18, 5, 0);
    final src = File('${tmp.path}/source.jpg')
      ..writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));
    final svc = CaptureService(
      clipboard: FakeClipboard(
        ClipboardContent(
          files: [src.path],
          imageBytes: Uint8List.fromList([9, 8, 7]),
          imageExtension: 'png',
        ),
      ),
      storage: storage,
    );

    final result = await svc.captureNow(tmp.path, now: now);

    expect(result.isSaved, isTrue);
    final attachments = Directory(VaultPaths.attachmentsDir(tmp.path))
        .listSync()
        .whereType<File>()
        .toList();
    expect(attachments, hasLength(1));
    expect(attachments.single.path, endsWith('.jpg'));
    expect(attachments.single.readAsBytesSync(), [1, 2, 3, 4]);
  });

  test('带点父目录中的无扩展名文件仍能作为附件保存', () async {
    final now = DateTime(2026, 8, 21, 18, 6, 0);
    final dottedDir = Directory('${tmp.path}/folder.with.dot')..createSync();
    final src = File('${dottedDir.path}/LICENSE')..writeAsStringSync('content');
    final svc = CaptureService(
      clipboard: FakeClipboard(ClipboardContent(files: [src.path])),
      storage: storage,
    );

    final result = await svc.captureNow(tmp.path, now: now);

    expect(result.isSaved, isTrue);
    final attachments = Directory(VaultPaths.attachmentsDir(tmp.path))
        .listSync()
        .whereType<File>()
        .toList();
    expect(attachments, hasLength(1));
    expect(
      attachments.single.uri.pathSegments.last,
      matches(RegExp(r'^20260821-180600-[0-9a-f]{4}$')),
    );
    expect(attachments.single.readAsStringSync(), 'content');
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
