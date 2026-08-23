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
  bool _feedbackVisible = false;
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

    if (disableAnimations) {
      final minimumDisplay = Future<void>.delayed(
        const Duration(milliseconds: 150),
      );
      _controller.stop();
      _sequence = PixelChestAtlas.capture;
      setState(() {
        _state = PetAnimationState.capturing;
        _waiting = false;
        _feedback = null;
        _frameIndex = PixelChestAtlas.capture.frames.last;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final resultFuture = _captureResultFuture();
      _finishReducedCapture(resultFuture, minimumDisplay);
      return;
    }

    _setState(PetAnimationState.capturing);
    final capturePlayback = _play(PixelChestAtlas.capture);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final resultFuture = _captureResultFuture();
    CaptureResult? readyResult;
    resultFuture.then(
      (value) => readyResult = value,
      onError: (Object _) =>
          readyResult = const CaptureResult(CaptureStatus.error),
    );
    await capturePlayback;
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
        _showFeedback('剪贴板为空');
        _setState(PetAnimationState.error);
        await _play(PixelChestAtlas.empty);
        break;
      case CaptureStatus.error:
        _showFeedback('保存失败');
        _setState(PetAnimationState.error);
        await _play(PixelChestAtlas.error);
        break;
    }

    if (!mounted) return;
    _setState(PetAnimationState.idle);
    _scheduleIdleBlink();
  }

  Future<CaptureResult> _captureResultFuture() {
    try {
      return widget.onCapture();
    } catch (_) {
      return Future.value(const CaptureResult(CaptureStatus.error));
    }
  }

  Future<void> _finishReducedCapture(
    Future<CaptureResult> resultFuture,
    Future<void> minimumDisplay,
  ) async {
    CaptureResult result = const CaptureResult(CaptureStatus.error);
    try {
      result = await resultFuture;
    } catch (_) {}
    await minimumDisplay;
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
      _feedbackVisible = _feedback != null;
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
    final frameIndex =
        _sequence.frames[frameOffset.clamp(0, _sequence.frames.length - 1)];
    if (_frameIndex == frameIndex || !mounted) return;
    setState(() => _frameIndex = frameIndex);
  }

  void _setState(PetAnimationState state) {
    setState(() {
      _state = state;
      if (state == PetAnimationState.capturing) {
        _feedback = null;
        _feedbackVisible = false;
      }
    });
  }

  void _showFeedback(String feedback) {
    setState(() {
      _feedback = feedback;
      _feedbackVisible = true;
    });
    _scheduleFeedbackClear();
  }

  Duration get _feedbackFadeDuration =>
      _disableAnimations == true ||
          Theme.of(context).platform == TargetPlatform.windows
      ? Duration.zero
      : const Duration(milliseconds: 120);

  void _scheduleFeedbackClear() {
    _feedbackTimer?.cancel();
    if (_feedback == null) return;
    final fadeDuration = _feedbackFadeDuration;
    final visibleDuration = Duration(
      milliseconds: 1400 - fadeDuration.inMilliseconds,
    );
    _feedbackTimer = Timer(visibleDuration, () {
      if (!mounted) return;
      if (fadeDuration == Duration.zero) {
        setState(() {
          _feedbackVisible = false;
          _feedback = null;
        });
        return;
      }
      setState(() => _feedbackVisible = false);
      _feedbackTimer = Timer(fadeDuration, () {
        if (mounted) setState(() => _feedback = null);
      });
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
      child: Column(
        key: _stateMarkerKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: PixelChestAtlas.displaySize,
            child: Stack(
              children: [
                PixelChestSprite(image: widget.atlas, frameIndex: _frameIndex),
                Positioned(
                  left: PixelChestAtlas.bodyLeft,
                  top: PixelChestAtlas.bodyTop,
                  width: PixelChestAtlas.bodyWidth,
                  height: PixelChestAtlas.bodyHeight,
                  child: Semantics(
                    button: true,
                    label: '保存到 INbox',
                    child: GestureDetector(
                      key: const Key('pet-visible-region'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _capture,
                      onPanUpdate: (details) => widget.onMove(details.delta),
                      onSecondaryTapUp: (details) =>
                          widget.onSecondaryTap(details.globalPosition),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedOpacity(
            opacity: _feedbackVisible ? 1 : 0,
            duration: _feedbackFadeDuration,
            child: IgnorePointer(
              ignoring: _feedback == null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onSecondaryTapUp: (details) =>
                    widget.onSecondaryTap(details.globalPosition),
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
            ),
          ),
        ],
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
