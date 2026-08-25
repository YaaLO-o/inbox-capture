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

final class OverlayState {
  final bool running;
  final bool overlayPermission;
  final bool notificationPermission;
  final bool vaultConfigured;

  const OverlayState({
    required this.running,
    required this.overlayPermission,
    required this.notificationPermission,
    required this.vaultConfigured,
  });

  factory OverlayState.fromMap(Map<Object?, Object?> map) => OverlayState(
    running: map['running'] as bool,
    overlayPermission: map['overlayPermission'] as bool,
    notificationPermission: map['notificationPermission'] as bool,
    vaultConfigured: map['vaultConfigured'] as bool,
  );
}

/// Thrown when an overlay start/stop request fails for a reason the UI can
/// surface to the user. The [code] matches the native error codes
/// (`OVERLAY_PERMISSION_DENIED`, `VAULT_UNAVAILABLE`, ...).
final class OverlayException implements Exception {
  final String code;
  final String? message;

  const OverlayException(this.code, [this.message]);

  @override
  String toString() => 'OverlayException($code): $message';
}

final class AndroidVaultSettings {
  static const _channel = MethodChannel('com.inbox.app/android_vault');

  const AndroidVaultSettings();

  Future<VaultDescriptor?> getVault() => _descriptor('getVault');

  Future<VaultDescriptor?> pickVault() => _descriptor('pickVault');

  Future<void> clearVault() => _channel.invokeMethod<void>('clearVault');

  Future<OverlayState> getOverlayState() async {
    final value = await _channel.invokeMethod<Object?>('getOverlayState');
    return OverlayState.fromMap(Map<Object?, Object?>.from(value! as Map));
  }

  /// Returns the current overlay-permission state. If the permission is not
  /// granted this launches the system "Display over other apps" settings page;
  /// the result is observed when the app resumes (see
  /// [WidgetsBindingObserver.didChangeAppLifecycleState]).
  Future<bool> requestOverlayPermission() async {
    final value = await _channel.invokeMethod<bool>('requestOverlayPermission');
    return value ?? false;
  }

  /// Requests the POST_NOTIFICATIONS permission on API 33+. On older API
  /// levels, or when no Activity is attached, returns the current state
  /// without prompting. Notification denial is non-fatal for the overlay.
  Future<bool> requestNotificationPermission() async {
    final value =
        await _channel.invokeMethod<bool>('requestNotificationPermission');
    return value ?? true;
  }

  Future<void> startOverlay() async {
    try {
      await _channel.invokeMethod<void>('startOverlay');
    } on PlatformException catch (error) {
      throw OverlayException(error.code, error.message);
    }
  }

  Future<void> stopOverlay() => _channel.invokeMethod<void>('stopOverlay');

  Future<void> openNotificationSettings() =>
      _channel.invokeMethod<void>('openNotificationSettings');

  Future<VaultDescriptor?> _descriptor(String method) async {
    final value = await _channel.invokeMethod<Object?>(method);
    if (value == null) return null;
    return VaultDescriptor.fromMap(Map<Object?, Object?>.from(value as Map));
  }
}
