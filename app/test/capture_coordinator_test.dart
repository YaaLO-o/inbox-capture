import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/capture_coordinator.dart';
import 'package:inbox_app/services/capture_service.dart';
import 'package:inbox_app/services/clipboard_service.dart';
import 'package:inbox_app/services/vault_storage.dart';

class _UnusedClipboard implements ClipboardReader {
  @override
  Future<ClipboardContent> read() => throw UnimplementedError();
}

class _UnusedStorage implements VaultStorage {
  @override
  Future<void> appendMarkdown(String vaultId, DateTime date, String markdown) =>
      throw UnimplementedError();

  @override
  Future<void> deleteAttachment(String vaultId, String fileName) =>
      throw UnimplementedError();

  @override
  Future<void> ensureLayout(String vaultId) => throw UnimplementedError();

  @override
  Future<void> importAttachment(
    String vaultId,
    AttachmentSource source,
    String fileName,
  ) => throw UnimplementedError();
}

class _FakeCaptureService extends CaptureService {
  _FakeCaptureService(this.results)
    : super(clipboard: _UnusedClipboard(), storage: _UnusedStorage());

  final List<FutureOr<CaptureResult> Function()> results;
  int calls = 0;

  @override
  Future<CaptureResult> captureNow(String vaultId, {DateTime? now}) async {
    final result = results[calls++]();
    return await result;
  }
}

void main() {
  test('saved capture publishes success then idle', () async {
    final service = _FakeCaptureService([
      () => const CaptureResult(CaptureStatus.saved),
    ]);
    final states = <CaptureFeedbackStatus>[];
    final coordinator = CaptureCoordinator(
      captureService: service,
      onStatusChanged: states.add,
      feedbackDuration: Duration.zero,
    );

    final result = await coordinator.capture('/vault');
    await Future<void>.delayed(Duration.zero);

    expect(result.status, CaptureStatus.saved);
    expect(states, [CaptureFeedbackStatus.success, CaptureFeedbackStatus.idle]);
    expect(service.calls, 1);
    coordinator.dispose();
  });

  test('non-saved capture publishes failure then idle', () async {
    final service = _FakeCaptureService([
      () => const CaptureResult(CaptureStatus.empty),
    ]);
    final states = <CaptureFeedbackStatus>[];
    final coordinator = CaptureCoordinator(
      captureService: service,
      onStatusChanged: states.add,
      feedbackDuration: Duration.zero,
    );

    final result = await coordinator.capture('/vault');
    await Future<void>.delayed(Duration.zero);

    expect(result.status, CaptureStatus.empty);
    expect(states, [CaptureFeedbackStatus.failure, CaptureFeedbackStatus.idle]);
    coordinator.dispose();
  });

  test('missing vault fails without calling CaptureService', () async {
    final service = _FakeCaptureService([]);
    final states = <CaptureFeedbackStatus>[];
    final coordinator = CaptureCoordinator(
      captureService: service,
      onStatusChanged: states.add,
      feedbackDuration: Duration.zero,
    );

    final result = await coordinator.capture(null);
    await Future<void>.delayed(Duration.zero);

    expect(result.status, CaptureStatus.vaultUnavailable);
    expect(service.calls, 0);
    expect(states, [CaptureFeedbackStatus.failure, CaptureFeedbackStatus.idle]);
    coordinator.dispose();
  });

  test(
    'menu and assistant triggers reuse the injected CaptureService',
    () async {
      final service = _FakeCaptureService([
        () => const CaptureResult(CaptureStatus.saved),
        () => const CaptureResult(CaptureStatus.error),
      ]);
      final coordinator = CaptureCoordinator(
        captureService: service,
        feedbackDuration: Duration.zero,
      );

      await coordinator.capture('/vault');
      await coordinator.capture('/vault');

      expect(service.calls, 2);
      coordinator.dispose();
    },
  );

  test('thrown errors become failure results and feedback', () async {
    final service = _FakeCaptureService([() => throw StateError('boom')]);
    final states = <CaptureFeedbackStatus>[];
    final coordinator = CaptureCoordinator(
      captureService: service,
      onStatusChanged: states.add,
      feedbackDuration: Duration.zero,
    );

    final result = await coordinator.capture('/vault');
    await Future<void>.delayed(Duration.zero);

    expect(result.status, CaptureStatus.error);
    expect(states, [CaptureFeedbackStatus.failure, CaptureFeedbackStatus.idle]);
    coordinator.dispose();
  });
}
