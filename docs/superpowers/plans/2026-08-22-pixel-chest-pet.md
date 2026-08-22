# Pixel Chest Pet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current circular Capture control with the approved quiet pixel chest pet while preserving the existing Capture, Vault, storage, clipboard, and platform-channel behavior on macOS and Windows.

**Architecture:** Keep `CapturePill` as the public composition shell used by `main.dart`. Move frame metadata and atlas drawing into focused pet files, and let `PixelChestPet` own only the UI state machine that converts an injected `Future<CaptureResult> Function()` into Idle, Capturing, Success, and Error animation sequences. Keep window movement and the existing right-click menu in `CapturePill`; use a native Windows color-key layer only for transparent background support.

**Tech Stack:** Flutter 3.47.1, Dart 3.13.1, `AnimationController`, `CustomPainter`, transparent PNG sprite atlas, Flutter widget tests, macOS AppKit runner, Windows C++ Win32 runner.

**Spec:** `docs/superpowers/specs/2026-08-22-pixel-chest-pet-design.md`

## Global Constraints

- Keep `CaptureService`, `ClipboardService`, `StorageService`, Capture models, Markdown output, Vault behavior, and both clipboard adapters unchanged.
- Keep `CapturePill({vaultPath, capture, onChangeVault})` as the entry point used by `main.dart`.
- Keep the pet window at exactly `132 × 132` logical pixels.
- Use one transparent PNG atlas with `32 × 32` pixel cells and integer `3×` rendering.
- Render with `FilterQuality.none`; every atlas pixel must have alpha `0` or `255`.
- Do not add Flame, Live2D, GIF, Animated WebP, audio, global input hooks, model import, or a new Flutter package dependency.
- Do not implement Hover animation, sleeping, long-idle modes, content-type-specific sprites, pet progression, sound, transparent-pixel click-through, position persistence, screen-edge clamping, or tray recovery in this version.
- Idle has no persistent label or continuous breathing loop.
- Success uses the close, settle, and one-frame latch highlight only.
- Error and Empty use safe short text; never display exception objects, native error strings, or file paths.
- The top `12` logical pixels of the visible `72 × 60` chest silhouette are the dedicated brass drag zone; the remaining visible body is the Capture zone.
- Preserve the existing `重新选择 Vault` and `退出` right-click actions.
- Keep BongoCat code and art out of the implementation. If concrete source code is later copied, stop and add the complete upstream MIT notice before continuing.
- Windows visual parity remains unverified until a real Windows run checks transparency, DPI, dragging, topmost behavior, and the context menu.

## File Map

| File | Responsibility |
| --- | --- |
| `app/assets/pet/pixel_chest_atlas.png` | Production 8-column by 3-row atlas containing 22 fixed 32 × 32 frames |
| `app/lib/ui/pet/pet_animation_manifest.dart` | Frame indices, sequence durations, atlas constants, state enum, and palette constants |
| `app/lib/ui/pet/pixel_chest_sprite.dart` | Decode the atlas once and paint one selected cell at integer 3× scale |
| `app/lib/ui/pet/pixel_chest_pet.dart` | Capture-result animation state, idle blink timer, safe feedback, semantics, and pet hit regions |
| `app/lib/ui/capture_pill.dart` | Existing public shell, native move callback, and existing context menu wiring |
| `app/lib/ui/window_surface.dart` | Shared choice of transparent macOS surface or Windows color-key surface |
| `app/windows/runner/win32_window.cpp` | Apply Win32 layered color-key transparency to the existing popup tool window |
| `app/test/pet_animation_manifest_test.dart` | Atlas dimensions, binary alpha, allowed palette, and frame manifest tests |
| `app/test/pixel_chest_sprite_test.dart` | Atlas source rectangle and painter behavior tests |
| `app/test/pixel_chest_pet_test.dart` | Async state transitions, safe feedback, reduced motion, and gesture separation tests |
| `app/test/capture_pill_test.dart` | Integration contract for Capture, move channel, and right-click menu |

---

### Task 1: Create the production atlas and immutable frame manifest

**Files:**
- Create: `app/assets/pet/pixel_chest_atlas.png`
- Create: `app/lib/ui/pet/pet_animation_manifest.dart`
- Create: `app/test/pet_animation_manifest_test.dart`
- Modify: `app/pubspec.yaml:53-63`

**Interfaces:**
- Consumes: Approved `32 × 32` cell, 3× rendering, palette, state timing, and 22-frame allocation from the spec.
- Produces: `PetAnimationState`, `PetFrameSequence`, and `PixelChestAtlas` constants used by every later task.

- [ ] **Step 1: Add the asset declaration before the asset exists**

Update the Flutter section in `app/pubspec.yaml`.

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/pet/pixel_chest_atlas.png
```

- [ ] **Step 2: Write the failing manifest and atlas integrity tests**

Create `app/test/pet_animation_manifest_test.dart` with these checks.

```dart
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/ui/pet/pet_animation_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pixel chest atlas uses the fixed 8 by 3 cell layout', () async {
    final data = await rootBundle.load(PixelChestAtlas.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();

    expect(frame.image.width, PixelChestAtlas.pixelWidth);
    expect(frame.image.height, PixelChestAtlas.pixelHeight);
    expect(PixelChestAtlas.pixelWidth, 256);
    expect(PixelChestAtlas.pixelHeight, 96);
    expect(PixelChestAtlas.frameCount, 22);
  });

  test('atlas uses binary alpha and the approved opaque palette', () async {
    final data = await rootBundle.load(PixelChestAtlas.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = bytes!.buffer.asUint8List();
    final seenOpaque = <int>{};

    for (var i = 0; i < rgba.length; i += 4) {
      final alpha = rgba[i + 3];
      expect(<int>{0, 255}, contains(alpha));
      if (alpha == 0) continue;
      seenOpaque.add((rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2]);
    }

    expect(seenOpaque.difference(PixelChestAtlas.allowedOpaqueRgb), isEmpty);
  });

  test('animation sequences match the approved durations and frame ranges', () {
    expect(PixelChestAtlas.capture.frames, [3, 4, 5, 6, 7, 8, 9]);
    expect(PixelChestAtlas.capture.totalDuration,
        const Duration(milliseconds: 364));
    expect(PixelChestAtlas.waiting.frames, [10, 11]);
    expect(PixelChestAtlas.waiting.loop, isTrue);
    expect(PixelChestAtlas.success.frames, [12, 13, 14, 15]);
    expect(PixelChestAtlas.success.totalDuration,
        const Duration(milliseconds: 440));
    expect(PixelChestAtlas.error.totalDuration,
        const Duration(milliseconds: 480));
    expect(PixelChestAtlas.empty.totalDuration,
        const Duration(milliseconds: 480));
  });
}
```

- [ ] **Step 3: Run the focused test and verify the missing implementation failure**

Run from `app/`.

```bash
flutter test test/pet_animation_manifest_test.dart
```

Expected result: compilation fails because `pet_animation_manifest.dart` and the atlas do not exist.

- [ ] **Step 4: Add the exact manifest**

Create `app/lib/ui/pet/pet_animation_manifest.dart`.

```dart
import 'package:flutter/material.dart';

enum PetAnimationState { idle, capturing, success, error }

class PetFrameSequence {
  final List<int> frames;
  final Duration frameDuration;
  final bool loop;

  const PetFrameSequence({
    required this.frames,
    required this.frameDuration,
    this.loop = false,
  });

  Duration get totalDuration => frameDuration * frames.length;
}

abstract final class PixelChestAtlas {
  static const assetPath = 'assets/pet/pixel_chest_atlas.png';
  static const cellSize = 32;
  static const columns = 8;
  static const rows = 3;
  static const frameCount = 22;
  static const pixelWidth = columns * cellSize;
  static const pixelHeight = rows * cellSize;
  static const displaySize = 96.0;
  static const dragHeight = 12.0;
  static const bodyLeft = 12.0;
  static const bodyTop = 36.0;
  static const bodyWidth = 72.0;
  static const bodyHeight = 60.0;

  static const outline = Color(0xFF2B1D32);
  static const woodDark = Color(0xFF6B3F2A);
  static const woodLight = Color(0xFF9B6240);
  static const brass = Color(0xFFC9903B);
  static const brassHighlight = Color(0xFFE8C268);
  static const amber = Color(0xFFF3A43B);
  static const captureCyan = Color(0xFF69C6D4);
  static const errorCoral = Color(0xFFC85B5B);
  static const paper = Color(0xFFE9E0CF);

  static const allowedOpaqueRgb = <int>{
    0x2B1D32,
    0x6B3F2A,
    0x9B6240,
    0xC9903B,
    0xE8C268,
    0xF3A43B,
    0x69C6D4,
    0xC85B5B,
    0xE9E0CF,
  };

  static const idle = PetFrameSequence(
    frames: [0],
    frameDuration: Duration(milliseconds: 1),
  );
  static const idleBlink = PetFrameSequence(
    frames: [0, 1, 2, 0],
    frameDuration: Duration(milliseconds: 90),
  );
  static const capture = PetFrameSequence(
    frames: [3, 4, 5, 6, 7, 8, 9],
    frameDuration: Duration(milliseconds: 52),
  );
  static const waiting = PetFrameSequence(
    frames: [10, 11],
    frameDuration: Duration(milliseconds: 180),
    loop: true,
  );
  static const success = PetFrameSequence(
    frames: [12, 13, 14, 15],
    frameDuration: Duration(milliseconds: 110),
  );
  static const error = PetFrameSequence(
    frames: [16, 17, 18, 19, 20],
    frameDuration: Duration(milliseconds: 96),
  );
  static const empty = PetFrameSequence(
    frames: [16, 21, 19, 15],
    frameDuration: Duration(milliseconds: 120),
  );
}
```

- [ ] **Step 5: Produce the original 22-frame pixel atlas**

Invoke the `imagegen` skill for a reference sheet, then redraw and normalize the final atlas on the fixed grid. Use this prompt for the reference only.

```text
Use case: stylized-concept
Asset type: production reference for a tiny desktop pixel sprite atlas
Primary request: one original compact square mimic chest called Click-Latch, closed chest with hidden uneven amber eyes and a central brass latch tongue; show idle blink, latch pop, opening, a pale paper card folding and being swallowed, two quiet waiting poses, a fast satisfied close, a one-frame latch highlight, paper stuck error, one left-right shake, and empty chew
Style: strict hard-edged 16-bit pixel art, no antialiasing, no gradients, no shadows outside the silhouette
Palette: #2B1D32 #6B3F2A #9B6240 #C9903B #E8C268 #F3A43B #69C6D4 #C85B5B #E9E0CF plus transparent
Constraints: original character, short teeth only, no long tongue, no cat, no known game mimic, no text, no logo, no watermark
```

The final committed PNG must meet all of these measurable requirements.

- Canvas is exactly `256 × 96` pixels.
- Grid is exactly eight columns and three rows of `32 × 32` cells.
- Frames `0` through `21` follow the manifest allocation.
- Closed body silhouette occupies about `24 × 20` pixels inside each cell.
- Every frame shares the same bottom baseline and horizontal center.
- Transparent pixels use alpha `0`; visible pixels use alpha `255`.
- Opaque pixels use only `allowedOpaqueRgb`.
- The idle frame contains no glow, particle, star, label, or external shadow.
- Frame 14 is the only latch-highlight frame.
- Error coral never covers the whole chest.

- [ ] **Step 6: Run the integrity test and inspect the atlas at 100% and 300%**

Run from `app/`.

```bash
flutter test test/pet_animation_manifest_test.dart
```

Expected result: all three tests pass.

Open the PNG at native size and 300% nearest-neighbor zoom. Confirm the fixed baseline, readable 72 × 60 closed silhouette, short teeth, and absence of semi-transparent pixels.

- [ ] **Step 7: Commit the atlas and manifest**

```bash
git add app/pubspec.yaml app/assets/pet/pixel_chest_atlas.png \
  app/lib/ui/pet/pet_animation_manifest.dart \
  app/test/pet_animation_manifest_test.dart
git commit -m "feat: add pixel chest sprite atlas"
```

---

### Task 2: Decode and paint one atlas frame without smoothing

**Files:**
- Create: `app/lib/ui/pet/pixel_chest_sprite.dart`
- Create: `app/test/pixel_chest_sprite_test.dart`
- Create: `app/test/goldens/pixel_chest_idle.png`
- Create: `app/test/goldens/pixel_chest_capture_open.png`

**Interfaces:**
- Consumes: `PixelChestAtlas.assetPath`, `cellSize`, `columns`, and `displaySize` from Task 1.
- Produces: `loadPixelChestAtlas(AssetBundle)`, `pixelChestSourceRect(int)`, and `PixelChestSprite(image, frameIndex)` for Task 3.

- [ ] **Step 1: Write failing source-rectangle and golden tests**

Create `app/test/pixel_chest_sprite_test.dart`.

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/ui/pet/pet_animation_manifest.dart';
import 'package:inbox_app/ui/pet/pixel_chest_sprite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frame source rectangles follow the 8-column atlas grid', () {
    expect(pixelChestSourceRect(0), const Rect.fromLTWH(0, 0, 32, 32));
    expect(pixelChestSourceRect(7), const Rect.fromLTWH(224, 0, 32, 32));
    expect(pixelChestSourceRect(8), const Rect.fromLTWH(0, 32, 32, 32));
    expect(pixelChestSourceRect(21), const Rect.fromLTWH(160, 64, 32, 32));
  });

  testWidgets('idle sprite paints at exactly 96 logical pixels', (tester) async {
    final image = await loadPixelChestAtlas(rootBundle);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: const Key('idle-boundary'),
            child: PixelChestSprite(image: image, frameIndex: 0),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(PixelChestSprite)),
        const Size.square(PixelChestAtlas.displaySize));
    await expectLater(
      find.byKey(const Key('idle-boundary')),
      matchesGoldenFile('goldens/pixel_chest_idle.png'),
    );
  });

  testWidgets('capture-open sprite matches its approved frame', (tester) async {
    final image = await loadPixelChestAtlas(rootBundle);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: const Key('capture-boundary'),
            child: PixelChestSprite(image: image, frameIndex: 6),
          ),
        ),
      ),
    );

    await expectLater(
      find.byKey(const Key('capture-boundary')),
      matchesGoldenFile('goldens/pixel_chest_capture_open.png'),
    );
  });
}
```

- [ ] **Step 2: Run the test and verify missing renderer failures**

```bash
cd app
flutter test test/pixel_chest_sprite_test.dart
```

Expected result: compilation fails because `pixel_chest_sprite.dart` does not exist.

- [ ] **Step 3: Implement atlas loading, source rectangles, and nearest-neighbor painting**

Create `app/lib/ui/pet/pixel_chest_sprite.dart`.

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pet_animation_manifest.dart';

Future<ui.Image> loadPixelChestAtlas(AssetBundle bundle) async {
  final data = await bundle.load(PixelChestAtlas.assetPath);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  return (await codec.getNextFrame()).image;
}

Rect pixelChestSourceRect(int frameIndex) {
  assert(frameIndex >= 0 && frameIndex < PixelChestAtlas.frameCount);
  final column = frameIndex % PixelChestAtlas.columns;
  final row = frameIndex ~/ PixelChestAtlas.columns;
  return Rect.fromLTWH(
    column * PixelChestAtlas.cellSize.toDouble(),
    row * PixelChestAtlas.cellSize.toDouble(),
    PixelChestAtlas.cellSize.toDouble(),
    PixelChestAtlas.cellSize.toDouble(),
  );
}

class PixelChestSprite extends StatelessWidget {
  final ui.Image image;
  final int frameIndex;

  const PixelChestSprite({
    super.key,
    required this.image,
    required this.frameIndex,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: PixelChestAtlas.displaySize,
      child: CustomPaint(
        painter: _PixelChestPainter(image: image, frameIndex: frameIndex),
      ),
    );
  }
}

class _PixelChestPainter extends CustomPainter {
  final ui.Image image;
  final int frameIndex;

  const _PixelChestPainter({required this.image, required this.frameIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    canvas.drawImageRect(
      image,
      pixelChestSourceRect(frameIndex),
      Offset.zero & size,
      paint,
    );
  }

  @override
  bool shouldRepaint(_PixelChestPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.frameIndex != frameIndex;
}
```

- [ ] **Step 4: Generate and visually approve the two golden files**

```bash
flutter test --update-goldens test/pixel_chest_sprite_test.dart
flutter test test/pixel_chest_sprite_test.dart
```

Expected result: tests pass. Inspect both golden PNGs and reject them if pixels are blurred, the baseline shifts, or frame 6 does not clearly show the paper entering the open chest.

- [ ] **Step 5: Commit the renderer**

```bash
git add app/lib/ui/pet/pixel_chest_sprite.dart \
  app/test/pixel_chest_sprite_test.dart app/test/goldens
git commit -m "feat: render pixel chest atlas frames"
```

---

### Task 3: Implement the Capture-result pet state machine

**Files:**
- Create: `app/lib/ui/pet/pixel_chest_pet.dart`
- Create: `app/test/pixel_chest_pet_test.dart`

**Interfaces:**
- Consumes: `Future<CaptureResult> Function() onCapture`, decoded atlas rendering from Task 2, and all sequences from Task 1.
- Produces: `PixelChestPet(onCapture, onMove, onSecondaryTap)` for `CapturePill` in Task 4.

- [ ] **Step 1: Write failing tests for fast success, slow success, repeat clicks, Empty, and Error**

Create `app/test/pixel_chest_pet_test.dart`. Use a decoded atlas and a `Completer<CaptureResult>` so tests control service timing.

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/services/capture_service.dart';
import 'package:inbox_app/ui/pet/pet_animation_manifest.dart';
import 'package:inbox_app/ui/pet/pixel_chest_pet.dart';
import 'package:inbox_app/ui/pet/pixel_chest_sprite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPet(
    WidgetTester tester, {
    required Future<CaptureResult> Function() onCapture,
    bool disableAnimations = false,
  }) async {
    final image = await loadPixelChestAtlas(rootBundle);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: PixelChestPet(
            atlas: image,
            onCapture: onCapture,
            onMove: (_) {},
            onSecondaryTap: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('fast success still completes the capture intro first', (tester) async {
    await pumpPet(
      tester,
      onCapture: () async => const CaptureResult(CaptureStatus.saved),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump();
    expect(find.byKey(const Key('pet-state-capturing')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('pet-state-capturing')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 64));
    expect(find.byKey(const Key('pet-state-success')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 440));
    expect(find.byKey(const Key('pet-state-idle')), findsOneWidget);
  });

  testWidgets('slow result enters and leaves the waiting loop', (tester) async {
    final completer = Completer<CaptureResult>();
    await pumpPet(tester, onCapture: () => completer.future);

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('pet-waiting')), findsOneWidget);

    completer.complete(const CaptureResult(CaptureStatus.saved));
    await tester.pump();
    expect(find.byKey(const Key('pet-state-success')), findsOneWidget);
  });

  testWidgets('capturing ignores repeated body clicks', (tester) async {
    final completer = Completer<CaptureResult>();
    var calls = 0;
    await pumpPet(tester, onCapture: () {
      calls += 1;
      return completer.future;
    });

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    expect(calls, 1);
  });

  testWidgets('empty uses safe text and returns to idle', (tester) async {
    await pumpPet(
      tester,
      onCapture: () async =>
          const CaptureResult(CaptureStatus.empty, message: '剪贴板为空'),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump(const Duration(milliseconds: 364));
    expect(find.text('剪贴板为空'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 480));
    expect(find.byKey(const Key('pet-state-idle')), findsOneWidget);
  });

  testWidgets('error never exposes raw exception text', (tester) async {
    await pumpPet(
      tester,
      onCapture: () async => const CaptureResult(
        CaptureStatus.error,
        message: '/Users/name/private-vault: permission denied',
      ),
    );

    await tester.tap(find.bySemanticsLabel('保存到 INbox'));
    await tester.pump(const Duration(milliseconds: 364));
    expect(find.text('保存失败'), findsOneWidget);
    expect(find.textContaining('private-vault'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the focused tests and verify the missing widget failure**

```bash
cd app
flutter test test/pixel_chest_pet_test.dart
```

Expected result: compilation fails because `pixel_chest_pet.dart` does not exist.

- [ ] **Step 3: Implement one animation controller and async result gating**

Create `app/lib/ui/pet/pixel_chest_pet.dart` with this public contract and internal flow.

```dart
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
}
```

The state implementation must use these exact rules.

```dart
Future<void> _capture() async {
  if (_state != PetAnimationState.idle) return;
  _cancelIdleBlink();
  _setState(PetAnimationState.capturing);

  CaptureResult? readyResult;
  final Future<CaptureResult> resultFuture =
      widget.onCapture().catchError(
        (Object _) => const CaptureResult(CaptureStatus.error),
      );
  resultFuture.then((value) => readyResult = value);

  await _play(PixelChestAtlas.capture);
  if (!mounted) return;

  final CaptureResult result;
  if (readyResult != null) {
    result = readyResult!;
  } else {
    _waiting = true;
    _playLoop(PixelChestAtlas.waiting);
    result = await resultFuture;
    _waiting = false;
    _controller.stop();
  }
  if (!mounted) return;

  switch (result.status) {
    case CaptureStatus.saved:
      _setState(PetAnimationState.success);
      await _play(PixelChestAtlas.success);
      break;
    case CaptureStatus.empty:
      _feedback = '剪贴板为空';
      _setState(PetAnimationState.error);
      await _play(PixelChestAtlas.empty);
      break;
    case CaptureStatus.error:
      _feedback = '保存失败';
      _setState(PetAnimationState.error);
      await _play(PixelChestAtlas.error);
      break;
  }

  if (!mounted) return;
  _setState(PetAnimationState.idle);
  _scheduleFeedbackClear();
  _scheduleIdleBlink();
}
```

Implement `_play`, `_playLoop`, `_setState`, `_scheduleFeedbackClear`, `_scheduleIdleBlink`, and `_cancelIdleBlink` in the same file. `_play` sets the controller duration to `sequence.totalDuration`, starts from zero, and maps elapsed controller value to `sequence.frames`. `_scheduleIdleBlink` selects a delay with `Duration(seconds: 20 + Random().nextInt(26))`. Cancel both timers and dispose the controller in `dispose()`.

Add stable test keys `pet-state-idle`, `pet-state-capturing`, `pet-state-success`, `pet-state-error`, and `pet-waiting` to the root state marker.

- [ ] **Step 4: Add the visual layout, safe label, and semantics**

The widget is a centered `Column` containing a fixed `96 × 96` interaction `Stack` and the optional feedback label below it. Paint the sprite across the stack, then place the Capture semantics and gesture only over the visible body below the brass drag strip. Omit persistent Idle, Capturing, and Success labels. Error feedback uses an opaque cream label below the sprite so Windows color-key transparency cannot tint antialiased text edges.

```dart
SizedBox.square(
  dimension: PixelChestAtlas.displaySize,
  child: Stack(
    children: [
      PixelChestSprite(image: widget.atlas, frameIndex: _frameIndex),
      Positioned(
        left: PixelChestAtlas.bodyLeft,
        top: PixelChestAtlas.bodyTop + PixelChestAtlas.dragHeight,
        width: PixelChestAtlas.bodyWidth,
        height: PixelChestAtlas.bodyHeight - PixelChestAtlas.dragHeight,
        child: Semantics(
          button: true,
          label: '保存到 INbox',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _capture,
          ),
        ),
      ),
    ],
  ),
)
```

Use `AnimatedOpacity` only for the feedback label. Give it a maximum width of `116`, a height of `20`, and an opaque `Color(0xFFF4EBDD)` background. Keep the complete column at or below `116` logical pixels high so it fits inside the fixed `132 × 132` window without resizing.

- [ ] **Step 5: Run the focused state tests**

```bash
flutter test test/pixel_chest_pet_test.dart
```

Expected result: all tests pass.

- [ ] **Step 6: Commit the state machine**

```bash
git add app/lib/ui/pet/pixel_chest_pet.dart app/test/pixel_chest_pet_test.dart
git commit -m "feat: animate capture results with chest pet"
```

---

### Task 4: Separate Capture, drag, context-menu, and reduced-motion behavior

**Files:**
- Modify: `app/lib/ui/pet/pixel_chest_pet.dart`
- Modify: `app/test/pixel_chest_pet_test.dart`
- Modify: `app/lib/ui/capture_pill.dart:1-253`
- Modify: `app/test/capture_pill_test.dart:1-54`

**Interfaces:**
- Consumes: `PixelChestPet` public callbacks from Task 3, `SettingsService.moveWindowBy`, `SettingsService.quit`, and the existing `CapturePill` constructor.
- Produces: A drop-in `CapturePill` replacement with the same constructor and native MethodChannel calls as the current widget.

- [ ] **Step 1: Add failing gesture-separation tests**

Extend `app/test/pixel_chest_pet_test.dart`.

Add `import 'package:flutter/gestures.dart';` for `kSecondaryMouseButton`.

```dart
testWidgets('drag handle moves without triggering capture', (tester) async {
  final image = await loadPixelChestAtlas(rootBundle);
  var captures = 0;
  final moves = <Offset>[];
  await tester.pumpWidget(MaterialApp(
    home: PixelChestPet(
      atlas: image,
      onCapture: () async {
        captures += 1;
        return const CaptureResult(CaptureStatus.saved);
      },
      onMove: moves.add,
      onSecondaryTap: (_) {},
    ),
  ));

  await tester.drag(find.byKey(const Key('pet-drag-handle')), const Offset(12, 7));
  expect(moves, isNotEmpty);
  expect(captures, 0);
});

testWidgets('right click reports its global position without capture', (tester) async {
  final image = await loadPixelChestAtlas(rootBundle);
  var captures = 0;
  Offset? menuPosition;
  await tester.pumpWidget(MaterialApp(
    home: PixelChestPet(
      atlas: image,
      onCapture: () async {
        captures += 1;
        return const CaptureResult(CaptureStatus.saved);
      },
      onMove: (_) {},
      onSecondaryTap: (position) => menuPosition = position,
    ),
  ));

  final center = tester.getCenter(find.bySemanticsLabel('保存到 INbox'));
  final gesture = await tester.startGesture(center, buttons: kSecondaryMouseButton);
  await gesture.up();
  expect(menuPosition, isNotNull);
  expect(captures, 0);
});
```

Add a reduced-motion test.

```dart
testWidgets('disableAnimations skips blink shake and waiting loops', (tester) async {
  final completer = Completer<CaptureResult>();
  await pumpPet(
    tester,
    disableAnimations: true,
    onCapture: () => completer.future,
  );

  await tester.tap(find.bySemanticsLabel('保存到 INbox'));
  await tester.pump(const Duration(milliseconds: 160));
  expect(find.byKey(const Key('pet-waiting')), findsNothing);

  completer.complete(const CaptureResult(CaptureStatus.error));
  await tester.pump();
  expect(find.text('保存失败'), findsOneWidget);
});
```

- [ ] **Step 2: Run the tests and verify gesture and reduced-motion failures**

```bash
cd app
flutter test test/pixel_chest_pet_test.dart
```

Expected result: the new tests fail because there is no dedicated drag handle or reduced-motion branch.

- [ ] **Step 3: Add a dedicated drag overlay and root secondary-click handler**

In `PixelChestPet`, place the drag overlay over the top brass strip of the visible chest. It has key `pet-drag-handle`, height `PixelChestAtlas.dragHeight`, and only `onPanUpdate`.

```dart
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
)
```

Wrap the visible pet region with `onSecondaryTapUp` and forward `details.globalPosition`. Do not attach `onTap` to the drag overlay.

- [ ] **Step 4: Add the reduced-motion branch**

At Capture time read `MediaQuery.disableAnimationsOf(context)`. When true, cancel idle animation, show the approved open static frame for `150` milliseconds, await the result without a waiting loop, switch directly to the closed frame, and show only safe Error or Empty text. Do not schedule idle blink while animations remain disabled.

- [ ] **Step 5: Replace the old circular control inside CapturePill**

Keep the class name and constructor. Keep `_showMenu` unchanged except for the callback source position. Remove `_DragHandle`, `_CaptureButton`, `_StatusLabel`, `_busy`, `_flash`, and `_doCapture` after `PixelChestPet` owns those responsibilities.

Load the atlas once before presenting the interactive pet.

```dart
late final Future<ui.Image> _atlasFuture;

@override
void initState() {
  super.initState();
  _atlasFuture = loadPixelChestAtlas(rootBundle);
}
```

Build the pet after the asset resolves.

```dart
FutureBuilder<ui.Image>(
  future: _atlasFuture,
  builder: (context, snapshot) {
    final atlas = snapshot.data;
    if (atlas == null) return const SizedBox.square(dimension: 96);
    return PixelChestPet(
      atlas: atlas,
      onCapture: () => widget.capture.captureNow(widget.vaultPath),
      onMove: (delta) => _settings.moveWindowBy(delta.dx, delta.dy),
      onSecondaryTap: (position) => _showMenu(menuContext, position),
    );
  },
)
```

- [ ] **Step 6: Rewrite CapturePill integration tests around behavior**

Update `app/test/capture_pill_test.dart` to assert these outcomes.

- The closed chest semantics label exists.
- `收`, `•••`, and `点击保存` are absent.
- Body click calls the fake Capture once.
- Drag produces only `moveWindowBy` MethodChannel calls.
- Right click shows `重新选择 Vault` and `退出`.
- Selecting `重新选择 Vault` calls `onChangeVault`.
- Selecting `退出` invokes the existing `quit` method.

Use a test-only subclass so the production constructor and service graph remain unchanged.

```dart
class FakeCaptureService extends CaptureService {
  int calls = 0;
  CaptureResult result;

  FakeCaptureService(this.result)
      : super(clipboard: FakeEmptyClipboard(), storage: StorageService());

  @override
  Future<CaptureResult> captureNow(String vaultPath, {DateTime? now}) async {
    calls += 1;
    return result;
  }
}

class FakeEmptyClipboard implements ClipboardReader {
  @override
  Future<ClipboardContent> read() async => const ClipboardContent();
}
```

Do not add an injectable service abstraction to production code for this test.

- [ ] **Step 7: Run all pet and shell widget tests**

```bash
flutter test test/pet_animation_manifest_test.dart \
  test/pixel_chest_sprite_test.dart \
  test/pixel_chest_pet_test.dart \
  test/capture_pill_test.dart
```

Expected result: all focused tests pass.

- [ ] **Step 8: Commit the integrated Capture UI**

```bash
git add app/lib/ui/pet/pixel_chest_pet.dart \
  app/lib/ui/capture_pill.dart \
  app/test/pixel_chest_pet_test.dart \
  app/test/capture_pill_test.dart
git commit -m "feat: replace capture pill with chest pet"
```

---

### Task 5: Add Windows color-key transparency without changing onboarding

**Files:**
- Create: `app/lib/ui/window_surface.dart`
- Create: `app/test/window_surface_test.dart`
- Modify: `app/lib/ui/capture_pill.dart`
- Modify: `app/windows/runner/win32_window.cpp:19-151`

**Interfaces:**
- Consumes: Existing `WS_POPUP`, `WS_EX_TOOLWINDOW`, `WS_EX_TOPMOST`, transparent macOS NSWindow, and the pet-only Flutter surface.
- Produces: `captureWindowSurfaceColor(TargetPlatform)` and a matching Win32 `RGB(255, 0, 255)` layered color key.

- [ ] **Step 1: Write the failing platform surface-color test**

Create `app/test/window_surface_test.dart`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/ui/window_surface.dart';

void main() {
  test('Windows uses the native color key and macOS remains transparent', () {
    expect(captureWindowSurfaceColor(TargetPlatform.windows),
        const Color(0xFFFF00FF));
    expect(captureWindowSurfaceColor(TargetPlatform.macOS), Colors.transparent);
  });
}
```

- [ ] **Step 2: Run the test and verify the missing helper failure**

```bash
cd app
flutter test test/window_surface_test.dart
```

Expected result: compilation fails because `window_surface.dart` does not exist.

- [ ] **Step 3: Add the platform surface helper and use it only for CapturePill**

Create `app/lib/ui/window_surface.dart`.

```dart
import 'package:flutter/material.dart';

const windowsTransparencyKey = Color(0xFFFF00FF);

Color captureWindowSurfaceColor(TargetPlatform platform) =>
    platform == TargetPlatform.windows
        ? windowsTransparencyKey
        : Colors.transparent;
```

In `CapturePill`, set the pet `Scaffold.backgroundColor` from `Theme.of(context).platform`. Do not change `OnboardingView`; its opaque dark background must remain intact.

```dart
backgroundColor: captureWindowSurfaceColor(Theme.of(context).platform),
```

- [ ] **Step 4: Add Win32 layered color-key transparency**

In `app/windows/runner/win32_window.cpp`, add the exact color key beside the window class constant.

```cpp
constexpr COLORREF kTransparencyKey = RGB(255, 0, 255);
```

Add `WS_EX_LAYERED` to the existing extended style.

```cpp
HWND window = CreateWindowEx(
    WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_LAYERED,
    window_class, title.c_str(), WS_POPUP,
    Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
    Scale(size.width, scale_factor), Scale(size.height, scale_factor),
    nullptr, nullptr, GetModuleHandle(nullptr), this);
```

Immediately after successful creation, set the exact key and retain full opacity for every non-key pixel.

```cpp
if (!SetLayeredWindowAttributes(window, kTransparencyKey, 255, LWA_COLORKEY)) {
  DestroyWindow(window);
  return false;
}
```

Do not add `WS_EX_TRANSPARENT`, `SetWindowCompositionAttribute`, acrylic, Mica, blur, a timer, or a topmost refresh loop.

- [ ] **Step 5: Run portable Dart verification on macOS**

```bash
flutter test test/window_surface_test.dart test/capture_pill_test.dart
dart analyze lib test
```

Expected result: tests and analysis pass.

- [ ] **Step 6: Trigger the existing Windows workflow and inspect its artifacts**

Push the branch or run the existing `Windows build` workflow manually. It already executes the required commands.

```text
flutter pub get
dart analyze lib test
flutter test
flutter build windows -v
```

Expected result: all recorded exit codes are zero and `windows-build-output` contains the Release runner.

- [ ] **Step 7: Perform Windows visual verification before claiming parity**

Run the built app on Windows at 100%, 150%, and 200% display scaling. For each scale, record one screenshot and verify all of the following.

- Magenta never appears.
- The area outside the chest is visually transparent.
- Sprite edges have no magenta fringe.
- The opaque Error label has clean text edges.
- The window remains topmost and absent from the taskbar.
- The context menu appears above the pet.
- Drag movement follows the pointer without a DPI-dependent jump.
- Onboarding remains an opaque 420 × 300 window.

If any item fails, report Windows transparency as unverified and stop before the final verification task. Do not replace the color-key method with a different native approach without a new design review.

- [ ] **Step 8: Commit the Windows surface work after build evidence exists**

```bash
git add app/lib/ui/window_surface.dart app/test/window_surface_test.dart \
  app/lib/ui/capture_pill.dart app/windows/runner/win32_window.cpp
git commit -m "feat: add transparent Windows pet surface"
```

---

### Task 6: Run full verification and record only feature-owned evidence

**Files:**
- Modify only if copied code exists: `THIRD_PARTY_NOTICES.md`

**Interfaces:**
- Consumes: The integrated pet, test evidence, macOS build result, Windows workflow result, and Windows visual checklist from Tasks 1 through 5.
- Produces: A truthful handoff with no unsupported cross-platform claims and no edits to pre-existing dirty project-status files.

- [ ] **Step 1: Run formatting and inspect the exact diff**

```bash
cd app
dart format \
  lib/ui/pet/pet_animation_manifest.dart \
  lib/ui/pet/pixel_chest_sprite.dart \
  lib/ui/pet/pixel_chest_pet.dart \
  lib/ui/capture_pill.dart \
  lib/ui/window_surface.dart \
  test/pet_animation_manifest_test.dart \
  test/pixel_chest_sprite_test.dart \
  test/pixel_chest_pet_test.dart \
  test/capture_pill_test.dart \
  test/window_surface_test.dart
cd ..
git diff --check
git diff --stat
```

Expected result: formatting completes, `git diff --check` prints nothing, and every changed file traces to this feature.

- [ ] **Step 2: Run the complete shared verification suite**

```bash
cd app
flutter pub get
dart analyze lib test
flutter test
flutter build macos --debug
```

Expected result: dependency resolution, analysis, all Flutter tests, and the macOS debug build exit with code zero.

- [ ] **Step 3: Run the macOS interaction checklist**

Launch the macOS debug build and verify these cases.

- Idle shows a quiet closed chest with no persistent text.
- Clicking the body saves one copied text item to the configured Vault.
- The paper enters before the success close begins.
- Success closes with one latch highlight and no star.
- Empty clipboard performs the empty chew and shows `剪贴板为空`.
- A forced write failure performs the stuck-paper animation and shows only `保存失败`.
- Dragging the top brass region moves the window and does not Capture.
- Right click exposes `重新选择 Vault` and `退出`.
- The window remains transparent, topmost, and available across Spaces.
- Reduced-motion mode removes idle, waiting, and shake loops while retaining text feedback.

- [ ] **Step 4: Perform the license decision check**

Compare the implementation diff with BongoCat. If no code or assets were copied, do not create a notice solely for research inspiration. If concrete BongoCat code or a substantial portion was copied, create `THIRD_PARTY_NOTICES.md` containing the complete MIT text, `Copyright (c) 2025 ayangweb`, the fixed commit `44f44bcf2b17b8e16463ad479a477a949d01cc9a`, copied files, and modifications.

- [ ] **Step 5: Review spec coverage and run final status checks**

```bash
git diff --check
git status --short
git log --oneline -6
```

Confirm that each spec section has evidence in these tasks.

| Spec area | Evidence |
| --- | --- |
| Character, palette, grid, frames | Task 1 atlas tests and visual review |
| Nearest-neighbor rendering | Task 2 source-rect and golden tests |
| Capture timing and result gating | Task 3 async widget tests |
| Drag, Capture, menu separation | Task 4 gesture and shell tests |
| Reduced motion | Task 4 reduced-motion test and macOS checklist |
| macOS window behavior | Task 6 debug build and interaction checklist |
| Windows transparency and DPI | Task 5 CI artifact and visual checklist |
| Safe feedback | Task 3 Error and Empty tests |
| License boundary | Task 6 license decision check |

- [ ] **Step 6: Commit only formatter or notice changes owned by this feature**

```bash
git add app/lib/ui/pet/pet_animation_manifest.dart \
  app/lib/ui/pet/pixel_chest_sprite.dart \
  app/lib/ui/pet/pixel_chest_pet.dart \
  app/lib/ui/capture_pill.dart \
  app/lib/ui/window_surface.dart \
  app/test/pet_animation_manifest_test.dart \
  app/test/pixel_chest_sprite_test.dart \
  app/test/pixel_chest_pet_test.dart \
  app/test/capture_pill_test.dart \
  app/test/window_surface_test.dart
test ! -f THIRD_PARTY_NOTICES.md || git add THIRD_PARTY_NOTICES.md
git diff --cached --quiet || git commit -m "style: format pixel chest pet files"
```

Do not modify or stage the pre-existing dirty `README.md`, `PROJECT_STATE.md`, `app/lib/services/storage_service.dart`, `app/test/capture_service_test.dart`, or macOS Runner project files. If formatting touches a file outside the exact feature list, inspect it and restore only the formatter change with a surgical patch rather than discarding user work.
