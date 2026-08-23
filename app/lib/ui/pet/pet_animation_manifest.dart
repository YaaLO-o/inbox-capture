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
    frames: [12, 21, 13, 15],
    frameDuration: Duration(milliseconds: 120),
  );
}
