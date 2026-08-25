import 'dart:typed_data';

abstract interface class VaultStorage {
  Future<void> ensureLayout(String vaultId);

  Future<void> importAttachment(
    String vaultId,
    AttachmentSource source,
    String fileName,
  );

  Future<void> appendMarkdown(String vaultId, DateTime date, String markdown);

  Future<void> deleteAttachment(String vaultId, String fileName);
}

final class VaultStorageException implements Exception {
  static const vaultUnavailable = 'vaultUnavailable';
  static const permissionDenied = 'permissionDenied';
  static const importFailed = 'importFailed';
  static const appendFailed = 'appendFailed';

  final String code;
  final String message;

  const VaultStorageException(this.code, this.message);
}

sealed class AttachmentSource {
  const AttachmentSource();
}

final class BytesAttachmentSource extends AttachmentSource {
  final Uint8List bytes;

  const BytesAttachmentSource(this.bytes);
}

final class FileAttachmentSource extends AttachmentSource {
  final String path;

  const FileAttachmentSource(this.path);
}

final class UriAttachmentSource extends AttachmentSource {
  final String uri;

  const UriAttachmentSource(this.uri);
}
