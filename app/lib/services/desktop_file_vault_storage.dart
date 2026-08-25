import 'dart:io';

import '../util/path_utils.dart';
import 'vault_storage.dart';

final class DesktopFileVaultStorage implements VaultStorage {
  const DesktopFileVaultStorage();

  @override
  Future<void> ensureLayout(String vaultId) async {
    try {
      await Directory(VaultPaths.captureDir(vaultId)).create(recursive: true);
      await Directory(VaultPaths.attachmentsDir(vaultId))
          .create(recursive: true);
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
