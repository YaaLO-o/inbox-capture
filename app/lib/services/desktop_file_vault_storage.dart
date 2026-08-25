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
      throw VaultStorageException('vaultUnavailable', error.message);
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
      throw VaultStorageException('importFailed', error.message);
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
      throw VaultStorageException('appendFailed', error.message);
    }
  }

  @override
  Future<void> deleteAttachment(String vaultId, String fileName) async {
    final file = File('${VaultPaths.attachmentsDir(vaultId)}/$fileName');
    if (await file.exists()) await file.delete();
  }
}
