import 'dart:async';

import '../models/capture.dart';
import '../models/capture_input.dart';
import '../util/id_gen.dart';
import 'clipboard_service.dart';
import 'markdown_formatter.dart';
import 'vault_storage.dart';

/// 一次 Capture 的结果，用于 UI 反馈。
enum CaptureStatus { saved, empty, vaultUnavailable, permissionDenied, error }

class CaptureResult {
  final CaptureStatus status;
  final String? message;
  final String? captureId;

  const CaptureResult(this.status, {this.message, this.captureId});

  bool get isSaved => status == CaptureStatus.saved;
}

/// Capture 编排：适配平台输入，串行落盘附件，并原子追加 Inbox。
class CaptureService {
  final ClipboardReader clipboard;
  final VaultStorage storage;
  final String Function(DateTime) idGenerator;
  Future<void> _queue = Future.value();
  DateTime? _lastCaptureAt;

  CaptureService({
    required this.clipboard,
    required this.storage,
    this.idGenerator = generateCaptureId,
  });

  Future<CaptureResult> captureNow(String vaultId, {DateTime? now}) async {
    final timestamp = now ?? DateTime.now();
    final last = _lastCaptureAt;
    if (last != null && timestamp.difference(last).inMilliseconds.abs() < 500) {
      return const CaptureResult(CaptureStatus.error, message: '操作过于频繁');
    }
    _lastCaptureAt = timestamp;
    return captureInput(
      vaultId,
      (await clipboard.read()).toCaptureInput(),
      now: timestamp,
    );
  }

  Future<CaptureResult> captureInput(
    String vaultId,
    CaptureInput input, {
    DateTime? now,
  }) {
    final completer = Completer<CaptureResult>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await _captureInput(vaultId, input, now: now));
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<CaptureResult> _captureInput(
    String vaultId,
    CaptureInput input, {
    DateTime? now,
  }) async {
    if (!input.hasContent) {
      return const CaptureResult(CaptureStatus.empty, message: '剪贴板为空');
    }

    final timestamp = now ?? DateTime.now();
    final id = idGenerator(timestamp);
    final completedFileNames = <String>[];
    try {
      await storage.ensureLayout(vaultId);
      final attachments = <Attachment>[];
      for (var index = 0; index < input.attachments.length; index++) {
        final inputAttachment = input.attachments[index];
        final suffix = index == 0 ? '' : '-$index';
        final extension = _safeExtension(inputAttachment.extension);
        final fileName = '$id$suffix${extension.isEmpty ? '' : '.$extension'}';
        await storage.importAttachment(
          vaultId,
          inputAttachment.source,
          fileName,
        );
        completedFileNames.add(fileName);
        attachments.add(
          Attachment(
            id: '$id$suffix',
            fileName: fileName,
            originalExtension: extension,
            mimeType: inputAttachment.mimeType,
            displayName: inputAttachment.displayName,
          ),
        );
      }
      final capture = Capture(
        id: id,
        createdAt: timestamp,
        text: input.text?.trim().isNotEmpty == true ? input.text!.trim() : null,
        attachments: attachments,
      );
      await storage.appendMarkdown(
        vaultId,
        DateTime(timestamp.year, timestamp.month, timestamp.day),
        const MarkdownFormatter().format(capture),
      );
      return CaptureResult(CaptureStatus.saved, captureId: id);
    } on VaultStorageException catch (error) {
      await _rollback(vaultId, completedFileNames);
      return CaptureResult(_statusFor(error), message: error.message);
    } catch (_) {
      await _rollback(vaultId, completedFileNames);
      return const CaptureResult(CaptureStatus.error);
    }
  }

  Future<void> _rollback(String vaultId, List<String> fileNames) async {
    for (final fileName in fileNames.reversed) {
      try {
        await storage.deleteAttachment(vaultId, fileName);
      } catch (_) {
        // The original transaction failure remains the result.
      }
    }
  }

  CaptureStatus _statusFor(VaultStorageException error) => switch (error.code) {
    VaultStorageException.vaultUnavailable => CaptureStatus.vaultUnavailable,
    VaultStorageException.permissionDenied => CaptureStatus.permissionDenied,
    _ => CaptureStatus.error,
  };

  String _safeExtension(String extension) {
    final normalized = extension.toLowerCase();
    return RegExp(r'^[a-z0-9]+$').hasMatch(normalized) ? normalized : '';
  }
}
