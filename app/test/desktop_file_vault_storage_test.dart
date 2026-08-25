import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/desktop_file_vault_storage.dart';
import 'package:inbox_app/services/vault_storage.dart';
import 'package:inbox_app/util/path_utils.dart';

void main() {
  test('defines the four canonical storage error codes', () {
    expect(VaultStorageException.vaultUnavailable, 'vaultUnavailable');
    expect(VaultStorageException.permissionDenied, 'permissionDenied');
    expect(VaultStorageException.importFailed, 'importFailed');
    expect(VaultStorageException.appendFailed, 'appendFailed');
  });

  test('maps a denied vault layout write to permissionDenied', () async {
    final root = await Directory.systemTemp.createTemp('inbox_storage_test_');
    final locked = Directory('${root.path}/locked')..createSync();
    await Process.run('chmod', ['000', locked.path]);
    addTearDown(() async {
      await Process.run('chmod', ['700', locked.path]);
      await root.delete(recursive: true);
    });

    await expectLater(
      const DesktopFileVaultStorage().ensureLayout(locked.path),
      throwsA(
        isA<VaultStorageException>().having(
          (error) => error.code,
          'code',
          VaultStorageException.permissionDenied,
        ),
      ),
    );
  }, skip: Platform.isWindows ? 'chmod permission test is POSIX-only' : false);

  test(
    'normalizes denied attachment deletion as a typed storage exception',
    () async {
      final root = await Directory.systemTemp.createTemp('inbox_storage_test_');
      final vault = Directory('${root.path}/vault')..createSync();
      final attachments = Directory(VaultPaths.attachmentsDir(vault.path))
        ..createSync(recursive: true);
      File('${attachments.path}/locked.bin').writeAsBytesSync([1]);
      await Process.run('chmod', ['500', attachments.path]);
      addTearDown(() async {
        await Process.run('chmod', ['700', attachments.path]);
        await root.delete(recursive: true);
      });

      await expectLater(
        const DesktopFileVaultStorage().deleteAttachment(
          vault.path,
          'locked.bin',
        ),
        throwsA(
          isA<VaultStorageException>().having(
            (error) => error.code,
            'code',
            VaultStorageException.permissionDenied,
          ),
        ),
      );
    },
    skip: Platform.isWindows ? 'chmod permission test is POSIX-only' : false,
  );
}
