import 'dart:io';

import '../util/path_utils.dart';
import 'vault_storage.dart';

final class DesktopFileVaultStorage implements VaultStorage {
  const DesktopFileVaultStorage();

  @override
  Future<void> ensureLayout(String vaultId) async {
    try {
      // 目录创建是瞬时操作，用同步 API 保证返回时布局已就绪，
      // 也避免在 widget 测试的 fake-async 区里被异步 IO 挂住。
      Directory(VaultPaths.captureDir(vaultId)).createSync(recursive: true);
      Directory(
        VaultPaths.attachmentsDir(vaultId),
      ).createSync(recursive: true);
    } on FileSystemException catch (error) {
      throw _storageException(error, VaultStorageException.vaultUnavailable);
    }
  }

  @override
  Future<void> importAttachment(
    String vaultId,
    AttachmentSource source,
    String fileName,
  ) async {
    await ensureLayout(vaultId);
    final target = File('${VaultPaths.attachmentsDir(vaultId)}/$fileName');
    try {
      switch (source) {
        case BytesAttachmentSource(:final bytes):
          await target.writeAsBytes(bytes, flush: true);
        case FileAttachmentSource(:final path):
          await File(path).copy(target.path);
        case UriAttachmentSource():
          throw UnsupportedError('URI attachment sources are not supported');
      }
    } on FileSystemException catch (error) {
      throw _storageException(error, VaultStorageException.importFailed);
    }
  }

  @override
  Future<void> appendMarkdown(
    String vaultId,
    DateTime date,
    String markdown,
  ) async {
    try {
      await File(VaultPaths.dailyInboxFile(vaultId, date))
          .writeAsString(markdown, mode: FileMode.append, flush: true);
    } on FileSystemException catch (error) {
      throw _storageException(error, VaultStorageException.appendFailed);
    }
  }

  @override
  Future<void> deleteAttachment(String vaultId, String fileName) async {
    final file = File('${VaultPaths.attachmentsDir(vaultId)}/$fileName');
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      throw _storageException(error, VaultStorageException.vaultUnavailable);
    }
  }

  VaultStorageException _storageException(
    FileSystemException error,
    String fallbackCode,
  ) => VaultStorageException(
    _isPermissionDenied(error)
        ? VaultStorageException.permissionDenied
        : fallbackCode,
    error.message,
  );

  bool _isPermissionDenied(FileSystemException error) {
    final errorCode = error.osError?.errorCode;
    return errorCode == 1 ||
        errorCode == 5 ||
        errorCode == 13 ||
        error.message.toLowerCase().contains('permission denied') ||
        error.message.toLowerCase().contains('access denied');
  }
}
