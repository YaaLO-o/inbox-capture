import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/android_vault_settings.dart';

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
      return switch (call.method) {
        'getVault' => <String, Object>{
          'id': 'content://provider/tree/primary%3AObsidian',
          'displayName': 'Obsidian',
          'accessible': true,
        },
        'pickVault' => <String, Object>{
          'id': 'content://provider/tree/primary%3ANotes',
          'displayName': 'Notes',
          'accessible': true,
        },
        'clearVault' => null,
        _ => throw MissingPluginException(),
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('restores the persisted Vault descriptor', () async {
    final descriptor = (await const AndroidVaultSettings().getVault())!;

    expect(descriptor.id, 'content://provider/tree/primary%3AObsidian');
    expect(descriptor.displayName, 'Obsidian');
    expect(descriptor.accessible, isTrue);
    expect(calls.single.method, 'getVault');
  });

  test('returns null when no Vault is persisted', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    expect(await const AndroidVaultSettings().getVault(), isNull);
  });

  test('picks and clears the Vault through the native channel', () async {
    final settings = const AndroidVaultSettings();

    final picked = await settings.pickVault();
    await settings.clearVault();

    expect(picked?.displayName, 'Notes');
    expect(calls.map((call) => call.method), ['pickVault', 'clearVault']);
  });
}
