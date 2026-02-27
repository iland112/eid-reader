import 'dart:typed_data';

import 'package:eid_reader/core/utils/nv21_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a minimal NV21 buffer with all Y pixels set to [yValue].
/// NV21 layout: [Y plane: w*h bytes][VU interleaved: w*h/2 bytes]
Uint8List _createNv21({
  required int width,
  required int height,
  required int yValue,
}) {
  final size = width * height + width * (height ~/ 2);
  final buffer = Uint8List(size);
  // Fill Y plane
  for (int i = 0; i < width * height; i++) {
    buffer[i] = yValue;
  }
  // VU plane left as 0 (irrelevant for glare scoring)
  return buffer;
}

/// Creates an NV21 buffer with the first [brightCount] Y pixels set to
/// [brightValue] and the rest to [darkValue].
Uint8List _createMixedNv21({
  required int width,
  required int height,
  required int brightCount,
  required int brightValue,
  required int darkValue,
}) {
  final totalPixels = width * height;
  final size = totalPixels + width * (height ~/ 2);
  final buffer = Uint8List(size);
  for (int i = 0; i < totalPixels; i++) {
    buffer[i] = i < brightCount ? brightValue : darkValue;
  }
  return buffer;
}

void main() {
  group('computeNv21GlareScore', () {
    test('all-black (Y=0) returns 0.0', () {
      final nv21 = _createNv21(width: 4, height: 4, yValue: 0);
      expect(computeNv21GlareScore(nv21, 4, 4), 0.0);
    });

    test('all-white (Y=255) returns 1.0', () {
      final nv21 = _createNv21(width: 4, height: 4, yValue: 255);
      expect(computeNv21GlareScore(nv21, 4, 4), 1.0);
    });

    test('mid-gray (Y=128) returns 0.0', () {
      final nv21 = _createNv21(width: 4, height: 4, yValue: 128);
      expect(computeNv21GlareScore(nv21, 4, 4), 0.0);
    });

    test('Y=240 (at threshold) returns 0.0', () {
      final nv21 = _createNv21(width: 4, height: 4, yValue: 240);
      expect(computeNv21GlareScore(nv21, 4, 4), 0.0);
    });

    test('Y=241 (just above threshold) returns 1.0', () {
      final nv21 = _createNv21(width: 4, height: 4, yValue: 241);
      expect(computeNv21GlareScore(nv21, 4, 4), 1.0);
    });

    test('50% bright pixels returns ~0.5', () {
      // 4x4 = 16 pixels, 8 bright (Y=250) + 8 dark (Y=100)
      final nv21 = _createMixedNv21(
        width: 4,
        height: 4,
        brightCount: 8,
        brightValue: 250,
        darkValue: 100,
      );
      expect(computeNv21GlareScore(nv21, 4, 4), 0.5);
    });

    test('25% bright pixels returns 0.25', () {
      // 4x4 = 16 pixels, 4 bright (Y=245) + 12 dark (Y=50)
      final nv21 = _createMixedNv21(
        width: 4,
        height: 4,
        brightCount: 4,
        brightValue: 245,
        darkValue: 50,
      );
      expect(computeNv21GlareScore(nv21, 4, 4), 0.25);
    });

    test('custom threshold works', () {
      // All pixels Y=200, threshold=190 → all above → 1.0
      final nv21 = _createNv21(width: 4, height: 4, yValue: 200);
      expect(computeNv21GlareScore(nv21, 4, 4, threshold: 190), 1.0);

      // Same pixels, default threshold=240 → none above → 0.0
      expect(computeNv21GlareScore(nv21, 4, 4), 0.0);
    });

    test('empty buffer returns 0.0', () {
      expect(computeNv21GlareScore(Uint8List(0), 4, 4), 0.0);
    });

    test('zero dimensions returns 0.0', () {
      final nv21 = _createNv21(width: 4, height: 4, yValue: 255);
      expect(computeNv21GlareScore(nv21, 0, 4), 0.0);
      expect(computeNv21GlareScore(nv21, 4, 0), 0.0);
      expect(computeNv21GlareScore(nv21, 0, 0), 0.0);
    });

    test('undersized buffer returns 0.0', () {
      // Buffer has only 4 bytes but claims 4x4 = 16 Y pixels
      final tiny = Uint8List(4);
      expect(computeNv21GlareScore(tiny, 4, 4), 0.0);
    });

    test('larger resolution produces correct ratio', () {
      // 10x10 = 100 pixels, 10 bright + 90 dark
      final nv21 = _createMixedNv21(
        width: 10,
        height: 10,
        brightCount: 10,
        brightValue: 250,
        darkValue: 100,
      );
      expect(computeNv21GlareScore(nv21, 10, 10), closeTo(0.1, 0.001));
    });
  });
}
