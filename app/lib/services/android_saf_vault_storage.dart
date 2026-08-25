import 'package:flutter/services.dart';

import 'vault_storage.dart';

final class AndroidSafVaultStorage implements VaultStorage {
  static const _channel = MethodChannel('com.inbox.app/android_vault');

  const AndroidSafVaultStorage();

  @override
  Future<void> ensureLayout(String vaultId) =>
      _invoke('ensureLayout', {'vaultId': vaultId});

  @override
  Future<void> importAttachment(
    String vaultId,
    AttachmentSource source,
    String fileName,
  ) {
    if (source is! UriAttachmentSource) {
      return Future.error(
        const VaultStorageException(
          VaultStorageException.importFailed,
          'Android attachments require a content URI',
        ),
      );
    }
    return _invoke('importUri', {
      'vaultId': vaultId,
      'sourceUri': source.uri,
      'fileName': fileName,
    });
  }

  @override
  Future<void> appendMarkdown(String vaultId, DateTime date, String markdown) =>
      _invoke('appendMarkdown', {
        'vaultId': vaultId,
        'date': _dateStamp(date),
        'markdown': markdown,
      });

  @override
  Future<void> deleteAttachment(String vaultId, String fileName) =>
      _invoke('deleteAttachment', {'vaultId': vaultId, 'fileName': fileName});

  Future<void> _invoke(String method, Map<String, Object> arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      final code = switch (error.code) {
        'VAULT_UNAVAILABLE' => VaultStorageException.vaultUnavailable,
        'PERMISSION_DENIED' => VaultStorageException.permissionDenied,
        'IMPORT_FAILED' => VaultStorageException.importFailed,
        'APPEND_FAILED' => VaultStorageException.appendFailed,
        _ => null,
      };
      if (code == null) rethrow;
      throw VaultStorageException(code, error.message ?? 'Vault write failed');
    }
  }

  String _dateStamp(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
