import 'dart:async';

import 'capture_service.dart';

/// UI-independent feedback meaning for any platform capture entry.
enum CaptureFeedbackStatus { idle, success, failure }

/// Routes every interactive capture through one [CaptureService] instance.
class CaptureCoordinator {
  CaptureCoordinator({
    required this.captureService,
    this.onStatusChanged,
    this.feedbackDuration = const Duration(milliseconds: 900),
  });

  final CaptureService captureService;
  final void Function(CaptureFeedbackStatus status)? onStatusChanged;
  final Duration feedbackDuration;
  Timer? _idleTimer;

  Future<CaptureResult> capture(String? vaultId) async {
    CaptureResult result;
    if (vaultId == null) {
      result = const CaptureResult(CaptureStatus.vaultUnavailable);
    } else {
      try {
        result = await captureService.captureNow(vaultId);
      } catch (_) {
        result = const CaptureResult(CaptureStatus.error);
      }
    }

    _publish(
      result.isSaved
          ? CaptureFeedbackStatus.success
          : CaptureFeedbackStatus.failure,
    );
    return result;
  }

  void _publish(CaptureFeedbackStatus status) {
    _idleTimer?.cancel();
    onStatusChanged?.call(status);
    _idleTimer = Timer(
      feedbackDuration,
      () => onStatusChanged?.call(CaptureFeedbackStatus.idle),
    );
  }

  void dispose() {
    _idleTimer?.cancel();
  }
}
