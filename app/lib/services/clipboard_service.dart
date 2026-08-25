import 'package:flutter/services.dart';

import '../models/capture_input.dart';
import 'vault_storage.dart';

/// 一次剪贴板读取的结果。
///
/// - 纯文字：[text] 非空。
/// - 图片：[imageBytes] 非空，带 [imageExtension]（原始格式或 png）。
/// - Finder 复制的本地文件：[files] 为本地文件绝对路径列表（V0.1 顺带支持，
///   实现简单则复制进 attachments，否则忽略）。
///
/// 三种可能同时存在；Capture 编排层按 文字/附件 分别处理。
class ClipboardContent {
  final String? text;
  final Uint8List? imageBytes;
  final String imageExtension; // 不含点，小写
  final String? imageMimeType;
  final List<String> files;

  const ClipboardContent({
    this.text,
    this.imageBytes,
    this.imageExtension = 'png',
    this.imageMimeType,
    this.files = const [],
  });

  bool get hasContent =>
      (text != null && text!.trim().isNotEmpty) ||
      imageBytes != null ||
      files.isNotEmpty;

  CaptureInput toCaptureInput() {
    final attachments = <CaptureAttachmentInput>[];
    if (files.isNotEmpty) {
      for (final file in files) {
        attachments.add(
          CaptureAttachmentInput(
            source: FileAttachmentSource(file),
            extension: _extensionOf(file),
            displayName: _baseNameOf(file),
          ),
        );
      }
    } else if (imageBytes != null) {
      final extension = _safeExtension(imageExtension);
      attachments.add(
        CaptureAttachmentInput(
          source: BytesAttachmentSource(imageBytes!),
          extension: extension.isEmpty ? 'png' : extension,
          mimeType: imageMimeType,
        ),
      );
    }
    return CaptureInput(
      source: CaptureSource.desktopClipboard,
      text: text,
      attachments: List.unmodifiable(attachments),
      usesDesktopFileNames: files.isNotEmpty,
    );
  }

  static String _extensionOf(String path) {
    final fileName = _baseNameOf(path);
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return '';
    return _safeExtension(fileName.substring(dot + 1));
  }

  static String _safeExtension(String extension) {
    final normalized = extension.toLowerCase();
    return RegExp(r'^[a-z0-9]+$').hasMatch(normalized) ? normalized : '';
  }

  static String _baseNameOf(String path) =>
      path.replaceAll('\\', '/').split('/').last;
}

/// 剪贴板读取接口，便于测试时注入假实现。
abstract class ClipboardReader {
  Future<ClipboardContent> read();
}

/// 读取 macOS 剪贴板。原生实现见 AppDelegate.swift。
class ClipboardService implements ClipboardReader {
  static const _channel = MethodChannel('com.inbox.app/clipboard');

  @override
  Future<ClipboardContent> read() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'readClipboard',
    );
    if (result == null) return const ClipboardContent();

    final text = result['text'] as String?;
    final rawBytes = result['imageBytes'] as Uint8List?;
    final ext = (result['imageExtension'] as String?)?.toLowerCase() ?? 'png';
    final mime = result['imageMimeType'] as String?;
    final rawFiles = result['files'];
    final files = <String>[];
    if (rawFiles is List) {
      for (final f in rawFiles) {
        if (f is String && f.isNotEmpty) files.add(f);
      }
    }
    final hasFiles = files.isNotEmpty;

    return ClipboardContent(
      text: text,
      imageBytes: hasFiles ? null : rawBytes,
      imageExtension: ext,
      imageMimeType: hasFiles ? null : mime,
      files: files,
    );
  }
}
