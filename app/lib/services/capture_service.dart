import 'dart:io';

import '../models/capture.dart';
import '../util/id_gen.dart';
import 'clipboard_service.dart';
import 'storage_service.dart';

/// 一次 Capture 的结果，用于 UI 反馈。
enum CaptureStatus { saved, empty, error }

class CaptureResult {
  final CaptureStatus status;
  final String? message;
  final String? captureId;

  const CaptureResult(this.status, {this.message, this.captureId});

  bool get isSaved => status == CaptureStatus.saved;
}

/// Capture 编排：读剪贴板 → 构建 Capture → 落盘附件 → 追加 Inbox。
///
/// 不做任何分类/摘要（见《方案》第十、十六节）。
class CaptureService {
  final ClipboardReader clipboard;
  final StorageService storage;

  /// 防止重复快速点击（见《方案》第十七节 测试 5）。
  DateTime? _lastCaptureAt;

  CaptureService({required this.clipboard, required this.storage});

  Future<CaptureResult> captureNow(String vaultPath, {DateTime? now}) async {
    final ts = now ?? DateTime.now();

    // 500ms 内的重复点击直接忽略，避免重复写入。
    final last = _lastCaptureAt;
    if (last != null && ts.difference(last).inMilliseconds.abs() < 500) {
      return const CaptureResult(CaptureStatus.error, message: '操作过于频繁');
    }
    _lastCaptureAt = ts;

    try {
      storage.ensureVaultLayout(vaultPath);

      final content = await clipboard.read();
      if (!content.hasContent) {
        return const CaptureResult(CaptureStatus.empty, message: '剪贴板为空');
      }

      final id = generateCaptureId(ts);
      final attachments = <Attachment>[];

      // 1) 图片：写入 attachments，保留原始扩展名；只有原始 bitmap 时落为 PNG。
      if (content.imageBytes != null) {
        final ext = content.imageExtension.isEmpty
            ? 'png'
            : content.imageExtension;
        final fileName = '$id.$ext';
        storage.writeAttachmentBytes(
          vaultPath,
          fileName,
          content.imageBytes!,
        );
        attachments.add(Attachment(
          id: id,
          fileName: fileName,
          originalExtension: ext,
          mimeType: content.imageMimeType,
        ));
      }

      // 2) Finder 复制的本地文件：复制进 attachments（V0.1 顺带支持）。
      for (var i = 0; i < content.files.length; i++) {
        final src = content.files[i];
        final ext = _extensionOf(src);
        // 多个文件时用同一 id + 序号，保证唯一。
        final suffix = content.files.length > 1 ? '-$i' : '';
        final baseName = '$id$suffix${ext.isEmpty ? '' : '.$ext'}';
        try {
          storage.copyAttachmentFile(vaultPath, src, baseName);
          attachments.add(Attachment(
            id: '$id$suffix',
            fileName: baseName,
            originalExtension: ext,
          ));
        } on FileSystemException catch (e) {
          // 单个文件复制失败不应让整个 Capture 崩溃；记录文字占位。
          // 这里不引入日志依赖，失败静默跳过该附件。
          // ignore: avoid_print
          print('skip attachment $src: ${e.message}');
        }
      }

      final text = (content.text?.trim().isNotEmpty ?? false)
          ? content.text!.trim()
          : null;

      final capture = Capture(
        id: id,
        createdAt: ts,
        text: text,
        attachments: attachments,
      );

      if (capture.isEmpty) {
        return const CaptureResult(CaptureStatus.empty, message: '剪贴板为空');
      }

      storage.appendCapture(vaultPath, capture);
      return CaptureResult(CaptureStatus.saved, captureId: id);
    } catch (e) {
      return CaptureResult(CaptureStatus.error, message: e.toString());
    }
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }
}
