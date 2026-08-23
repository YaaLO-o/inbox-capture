import 'dart:io';

import '../models/capture.dart';
import '../util/path_utils.dart';

/// Obsidian Vault 写入层。
///
/// 唯一存储层：所有内容都是普通 Markdown 与普通文件（见《方案》第二节）。
/// - 每日一个 `Universal Capture/YYYY-MM-DD.md`，只追加，绝不覆盖。
/// - 附件写入 `Universal Capture/attachments/`。
class StorageService {
  /// 确保 Vault 的 Universal Capture 与 attachments 目录存在。
  void ensureVaultLayout(String vaultPath) {
    final capture = Directory(VaultPaths.captureDir(vaultPath));
    if (!capture.existsSync()) {
      capture.createSync(recursive: true);
    }
    final att = Directory(VaultPaths.attachmentsDir(vaultPath));
    if (!att.existsSync()) {
      att.createSync(recursive: true);
    }
  }

  /// 将 Capture 追加写入当天的 Inbox Markdown 文件。
  ///
  /// 文件不存在时直接写入首条 Capture；存在时只在末尾追加，绝不动已有内容。
  /// 日期由每日文件名表达，不在正文重复。同步写入，保证调用返回时已落盘。
  void appendCapture(String vaultPath, Capture capture) {
    ensureVaultLayout(vaultPath);
    final date = DateTime(
      capture.createdAt.year,
      capture.createdAt.month,
      capture.createdAt.day,
    );
    final file = File(VaultPaths.dailyInboxFile(vaultPath, date));
    final buf = StringBuffer();

    buf.writeln('## ${VaultPaths.timeStamp(capture.createdAt)}');
    buf.writeln();
    buf.writeln('<!-- capture:id=${capture.id} -->');
    buf.writeln();

    if (capture.text != null && capture.text!.trim().isNotEmpty) {
      buf.writeln(capture.text!.trim());
      buf.writeln();
    }

    for (final a in capture.attachments) {
      final ref = VaultPaths.embedRef(a.fileName);
      final displayName = _safeDisplayName(a.displayName);
      if (a.isImage) {
        buf.writeln('![[$ref]]');
      } else if (displayName != null) {
        buf.writeln('[[$ref|$displayName]]');
      } else {
        buf.writeln('[[$ref]]');
      }
      buf.writeln();
    }

    buf.writeln('---');
    buf.writeln();

    file.writeAsStringSync(buf.toString(), mode: FileMode.append, flush: true);
  }

  String? _safeDisplayName(String? displayName) {
    if (displayName == null) return null;
    final oneLine = displayName.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
    final safe = oneLine
        .replaceAll(RegExp(r'[#|^:%\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return safe.isEmpty ? null : safe;
  }

  /// 将字节写入 attachments 目录，文件名由调用方给定。
  String writeAttachmentBytes(
    String vaultPath,
    String fileName,
    List<int> bytes,
  ) {
    ensureVaultLayout(vaultPath);
    final target = '${VaultPaths.attachmentsDir(vaultPath)}/$fileName';
    final f = File(target);
    f.writeAsBytesSync(bytes, flush: true);
    return target;
  }

  /// 将 Finder 复制的本地文件复制进 attachments 目录。
  ///
  /// 返回新文件名；若源文件不存在或复制失败则抛出异常，由上层处理。
  String copyAttachmentFile(
    String vaultPath,
    String sourcePath,
    String fileName,
  ) {
    ensureVaultLayout(vaultPath);
    final src = File(sourcePath);
    if (!src.existsSync()) {
      throw FileSystemException('源文件不存在', sourcePath);
    }
    final target = '${VaultPaths.attachmentsDir(vaultPath)}/$fileName';
    src.copySync(target);
    return target;
  }
}
