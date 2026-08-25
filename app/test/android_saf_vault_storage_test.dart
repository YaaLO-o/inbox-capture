import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/android_saf_vault_storage.dart';
import 'package:inbox_app/services/vault_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.inbox.app/android_vault');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'serializes layout, URI import, append, and delete operations',
    () async {
      const storage = AndroidSafVaultStorage();
      const vaultId = 'content://provider/tree/primary%3AObsidian';

      await storage.ensureLayout(vaultId);
      await storage.importAttachment(
        vaultId,
        const UriAttachmentSource('content://source/document/report'),
        'capture.pdf',
      );
      await storage.appendMarkdown(
        vaultId,
        DateTime(2026, 8, 24),
        '## 09:30\n\n---\n\n',
      );
      await storage.deleteAttachment(vaultId, 'capture.pdf');

      expect(calls[0], isA<MethodCall>());
      expect(calls[0].method, 'ensureLayout');
      expect(calls[0].arguments, {'vaultId': vaultId});
      expect(calls[1].method, 'importUri');
      expect(calls[1].arguments, {
        'vaultId': vaultId,
        'sourceUri': 'content://source/document/report',
        'fileName': 'capture.pdf',
      });
      expect(calls[2].method, 'appendMarkdown');
      expect(calls[2].arguments, {
        'vaultId': vaultId,
        'date': '2026-08-24',
        'markdown': '## 09:30\n\n---\n\n',
      });
      expect(calls[3].method, 'deleteAttachment');
      expect(calls[3].arguments, {
        'vaultId': vaultId,
        'fileName': 'capture.pdf',
      });
    },
  );

  test(
    'rejects non-URI attachment sources before calling native code',
    () async {
      const storage = AndroidSafVaultStorage();

      await expectLater(
        storage.importAttachment(
          'content://provider/tree/vault',
          const FileAttachmentSource('/tmp/report.pdf'),
          'capture.pdf',
        ),
        throwsA(
          isA<VaultStorageException>().having(
            (error) => error.code,
            'code',
            VaultStorageException.importFailed,
          ),
        ),
      );
      expect(calls, isEmpty);
    },
  );

  for (final entry in <(String, String, String)>[
    (
      'ensureLayout',
      'VAULT_UNAVAILABLE',
      VaultStorageException.vaultUnavailable,
    ),
    ('importUri', 'IMPORT_FAILED', VaultStorageException.importFailed),
    ('appendMarkdown', 'APPEND_FAILED', VaultStorageException.appendFailed),
    (
      'deleteAttachment',
      'PERMISSION_DENIED',
      VaultStorageException.permissionDenied,
    ),
  ]) {
    test('maps ${entry.$2} to ${entry.$3}', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: entry.$2, message: 'native failure');
      });
      const storage = AndroidSafVaultStorage();

      final operation = switch (entry.$1) {
        'ensureLayout' => storage.ensureLayout('content://vault/tree'),
        'importUri' => storage.importAttachment(
          'content://vault/tree',
          const UriAttachmentSource('content://source/document'),
          'capture.bin',
        ),
        'appendMarkdown' => storage.appendMarkdown(
          'content://vault/tree',
          DateTime(2026, 8, 24),
          'markdown',
        ),
        'deleteAttachment' => storage.deleteAttachment(
          'content://vault/tree',
          'capture.bin',
        ),
        _ => throw StateError('unsupported test operation'),
      };

      await expectLater(
        operation,
        throwsA(
          isA<VaultStorageException>()
              .having((error) => error.code, 'code', entry.$3)
              .having((error) => error.message, 'message', 'native failure'),
        ),
      );
    });
  }
}
