import 'package:flutter/services.dart';

final class VaultDescriptor {
  final String id;
  final String displayName;
  final bool accessible;

  const VaultDescriptor({
    required this.id,
    required this.displayName,
    required this.accessible,
  });

  factory VaultDescriptor.fromMap(Map<Object?, Object?> map) => VaultDescriptor(
    id: map['id'] as String,
    displayName: map['displayName'] as String,
    accessible: map['accessible'] as bool,
  );
}

final class AndroidVaultSettings {
  static const _channel = MethodChannel('com.inbox.app/android_vault');

  const AndroidVaultSettings();

  Future<VaultDescriptor?> getVault() => _descriptor('getVault');

  Future<VaultDescriptor?> pickVault() => _descriptor('pickVault');

  Future<void> clearVault() => _channel.invokeMethod<void>('clearVault');

  Future<VaultDescriptor?> _descriptor(String method) async {
    final value = await _channel.invokeMethod<Object?>(method);
    if (value == null) return null;
    return VaultDescriptor.fromMap(Map<Object?, Object?>.from(value as Map));
  }
}
