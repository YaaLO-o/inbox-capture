import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/capture_service.dart';
import 'pet_animation_manifest.dart';
import 'pixel_chest_sprite.dart';

class PixelChestPet extends StatefulWidget {
  final ui.Image atlas;
  final Future<CaptureResult> Function() onCapture;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onSecondaryTap;

  const PixelChestPet({
    super.key,
    required this.atlas,
    required this.onCapture,
    required this.onMove,
    required this.onSecondaryTap,
  });

  @override
  State<PixelChestPet> createState() => _PixelChestPetState();
}

class _PixelChestPetState extends State<PixelChestPet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  PetAnimationState _state = PetAnimationState.idle;
  PetFrameSequence _sequence = PixelChestAtlas.idle;
  int _frameIndex = PixelChestAtlas.idle.frames.first;
  bool _waiting = false;
  String? _feedback;
  Timer? _feedbackTimer;
  Timer? _idleBlinkTimer;
  bool? _disableAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)..addListener(_updateFrame);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations) {
      _cancelIdleBlink();
      if (_state == PetAnimationState.idle) {
        _controller.stop();
        _sequence = PixelChestAtlas.idle;
        _frameIndex = PixelChestAtlas.idle.frames.first;
      }
    } else if (_state == PetAnimationState.idle) {
      _scheduleIdleBlink();
    }
  }

  Future<void> _capture() async {
    if (_state != PetAnimationState.idle) return;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    _cancelIdleBlink();
    _feedbackTimer?.cancel();

    final resultFuture = _captureResultFuture();

    if (disableAnimations) {
      _controller.stop();
      _sequence = PixelChestAtlas.capture;
      setState(() {
        _state = PetAnimationState.capturing;
        _waiting = false;
        _feedback = null;
        _frameIndex = PixelChestAtlas.capture.frames.last;
      });
      _finishReducedCapture(resultFuture);
      return;
    }

    CaptureResult? readyResult;
    resultFuture.then(
      (value) => readyResult = value,
      onError: (Object _) =>
          readyResult = const CaptureResult(CaptureStatus.error),
    );
    _setState(PetAnimationState.capturing);
    await _play(PixelChestAtlas.capture);
    if (!mounted) return;

    CaptureResult result = const CaptureResult(CaptureStatus.error);
    if (readyResult != null) {
      result = readyResult!;
    } else {
      setState(() => _waiting = true);
      _playLoop(PixelChestAtlas.waiting);
      try {
        result = await resultFuture;
      } catch (_) {}
      if (!mounted) return;
      setState(() => _waiting = false);
      _controller.stop();
    }
    if (!mounted) return;

    switch (result.status) {
      case CaptureStatus.saved:
        _setState(PetAnimationState.success);
        await _play(PixelChestAtlas.success);
        break;
      case CaptureStatus.empty:
        setState(() => _feedback = '剪贴板为空');
        _setState(PetAnimationState.error);
        await _play(PixelChestAtlas.empty);
        break;
      case CaptureStatus.error:
        setState(() => _feedback = '保存失败');
        _setState(PetAnimationState.error);
        await _play(PixelChestAtlas.error);
        break;
    }

    if (!mounted) return;
    _setState(PetAnimationState.idle);
    _scheduleFeedbackClear();
    _scheduleIdleBlink();
  }

  Future<CaptureResult> _captureResultFuture() {
    try {
      return widget.onCapture();
    } catch (_) {
      return Future.value(const CaptureResult(CaptureStatus.error));
    }
  }

  Future<void> _finishReducedCapture(Future<CaptureResult> resultFuture) async {
    final minimumDelay = Completer<void>();
    Future<void>.delayed(
      const Duration(milliseconds: 150),
      minimumDelay.complete,
    );

    CaptureResult result = const CaptureResult(CaptureStatus.error);
    try {
      result = await resultFuture;
    } catch (_) {}
    if (!minimumDelay.isCompleted) await minimumDelay.future;
    if (!mounted) return;
    setState(() {
      _state = PetAnimationState.idle;
      _sequence = PixelChestAtlas.idle;
      _frameIndex = PixelChestAtlas.idle.frames.first;
      _feedback = switch (result.status) {
        CaptureStatus.saved => null,
        CaptureStatus.empty => '剪贴板为空',
        CaptureStatus.error => '保存失败',
      };
    });
    _scheduleFeedbackClear();
  }

  Future<void> _play(PetFrameSequence sequence) {
    _sequence = sequence;
    _controller
      ..stop()
      ..duration = sequence.totalDuration
      ..value = 0;
    _updateFrame();
    return _controller.forward();
  }

  void _playLoop(PetFrameSequence sequence) {
    _sequence = sequence;
    _controller
      ..stop()
      ..duration = sequence.totalDuration
      ..value = 0
      ..repeat();
    _updateFrame();
  }

  void _updateFrame() {
    final frameOffset = (_controller.value * _sequence.frames.length).floor();
    final frameIndex = _sequence
        .frames[frameOffset.clamp(0, _sequence.frames.length - 1) as int];
    if (_frameIndex == frameIndex || !mounted) return;
    setState(() => _frameIndex = frameIndex);
  }

  void _setState(PetAnimationState state) {
    setState(() {
      _state = state;
      if (state == PetAnimationState.capturing) {
        _feedback = null;
      }
    });
  }

  void _scheduleFeedbackClear() {
    _feedbackTimer?.cancel();
    if (_feedback == null) return;
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  void _scheduleIdleBlink() {
    _cancelIdleBlink();
    if (_disableAnimations == true) return;
    _idleBlinkTimer = Timer(
      Duration(seconds: 20 + Random().nextInt(26)),
      () async {
        if (!mounted || _state != PetAnimationState.idle) return;
        await _play(PixelChestAtlas.idleBlink);
        if (!mounted || _state != PetAnimationState.idle) return;
        _scheduleIdleBlink();
      },
    );
  }

  void _cancelIdleBlink() {
    _idleBlinkTimer?.cancel();
    _idleBlinkTimer = null;
  }

  Key get _stateMarkerKey {
    if (_waiting) return const Key('pet-waiting');
    return switch (_state) {
      PetAnimationState.idle => const Key('pet-state-idle'),
      PetAnimationState.capturing => const Key('pet-state-capturing'),
      PetAnimationState.success => const Key('pet-state-success'),
      PetAnimationState.error => const Key('pet-state-error'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (details) =>
            widget.onSecondaryTap(details.globalPosition),
        child: Column(
          key: _stateMarkerKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: PixelChestAtlas.displaySize,
              child: Stack(
                children: [
                  PixelChestSprite(
                    image: widget.atlas,
                    frameIndex: _frameIndex,
                  ),
                  Positioned(
                    left: PixelChestAtlas.bodyLeft,
                    top: PixelChestAtlas.bodyTop + PixelChestAtlas.dragHeight,
                    width: PixelChestAtlas.bodyWidth,
                    height:
                        PixelChestAtlas.bodyHeight - PixelChestAtlas.dragHeight,
                    child: Semantics(
                      button: true,
                      label: '保存到 INbox',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _capture,
                      ),
                    ),
                  ),
                  Positioned(
                    left: PixelChestAtlas.bodyLeft,
                    top: PixelChestAtlas.bodyTop,
                    width: PixelChestAtlas.bodyWidth,
                    height: PixelChestAtlas.dragHeight,
                    child: GestureDetector(
                      key: const Key('pet-drag-handle'),
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) => widget.onMove(details.delta),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: _feedback == null ? 0 : 1,
              duration: _disableAnimations == true
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              child: SizedBox(
                width: 116,
                height: 20,
                child: ColoredBox(
                  color: const Color(0xFFF4EBDD),
                  child: Center(
                    child: Text(
                      _feedback ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _cancelIdleBlink();
    _controller.dispose();
    super.dispose();
  }
}
