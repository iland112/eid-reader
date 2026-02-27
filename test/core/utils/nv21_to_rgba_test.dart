import 'dart:typed_data';

import 'package:eid_reader/core/utils/nv21_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a test NV21 buffer with uniform Y, U, V values.
Uint8List _createNv21({
  required int width,
  required int height,
  required int y,
  required int u,
  required int v,
}) {
  final yPlaneSize = width * height;
  final uvPlaneSize = width * (height ~/ 2);
  final buf = Uint8List(yPlaneSize + uvPlaneSize);

  // Fill Y plane
  for (var i = 0; i < yPlaneSize; i++) {
    buf[i] = y;
  }

  // Fill VU interleaved plane (NV21 = V first, then U)
  for (var i = 0; i < uvPlaneSize; i += 2) {
    buf[yPlaneSize + i] = v;
    buf[yPlaneSize + i + 1] = u;
  }

  return buf;
}

/// Creates a test NV21 buffer with per-pixel Y values for position testing.
/// Y values encode position: Y = (row * width + col) % 256.
/// U=128, V=128 (neutral chroma → grayscale).
Uint8List _createPositionNv21({required int width, required int height}) {
  final yPlaneSize = width * height;
  final uvPlaneSize = width * (height ~/ 2);
  final buf = Uint8List(yPlaneSize + uvPlaneSize);

  // Y plane: position-encoded
  for (var row = 0; row < height; row++) {
    for (var col = 0; col < width; col++) {
      buf[row * width + col] = (row * width + col) % 256;
    }
  }

  // VU plane: neutral (128, 128) → R≈G≈B≈Y
  for (var i = 0; i < uvPlaneSize; i += 2) {
    buf[yPlaneSize + i] = 128; // V
    buf[yPlaneSize + i + 1] = 128; // U
  }

  return buf;
}

void main() {
  group('nv21ToRgba', () {
    test('converts white NV21 to white RGBA', () {
      // Y=255, U=128, V=128 → R≈255, G≈255, B≈255
      final nv21 = _createNv21(width: 4, height: 4, y: 255, u: 128, v: 128);
      final result = nv21ToRgba(nv21Bytes: nv21, width: 4, height: 4);

      expect(result.width, 4);
      expect(result.height, 4);
      expect(result.rgba.length, 4 * 4 * 4); // 4x4 pixels x 4 bytes

      // Check first pixel is approximately white
      expect(result.rgba[0], greaterThan(250)); // R
      expect(result.rgba[1], greaterThan(250)); // G
      expect(result.rgba[2], greaterThan(250)); // B
      expect(result.rgba[3], 255); // A
    });

    test('converts black NV21 to black RGBA', () {
      // Y=0, U=128, V=128 → R≈0, G≈0, B≈0
      final nv21 = _createNv21(width: 4, height: 4, y: 0, u: 128, v: 128);
      final result = nv21ToRgba(nv21Bytes: nv21, width: 4, height: 4);

      expect(result.rgba[0], lessThan(5)); // R
      expect(result.rgba[1], lessThan(5)); // G
      expect(result.rgba[2], lessThan(5)); // B
      expect(result.rgba[3], 255); // A
    });

    test('converts red NV21 to red-dominant RGBA', () {
      // Pure red in BT.601: Y≈82, U≈90, V≈240
      final nv21 = _createNv21(width: 4, height: 4, y: 82, u: 90, v: 240);
      final result = nv21ToRgba(nv21Bytes: nv21, width: 4, height: 4);

      expect(result.rgba[0], greaterThan(200)); // R should be high
      expect(result.rgba[1], lessThan(50)); // G should be low
      expect(result.rgba[2], lessThan(50)); // B should be low
    });

    test('rotation 0° preserves dimensions', () {
      final nv21 = _createNv21(width: 6, height: 4, y: 128, u: 128, v: 128);
      final result = nv21ToRgba(
        nv21Bytes: nv21,
        width: 6,
        height: 4,
        rotationDegrees: 0,
      );

      expect(result.width, 6);
      expect(result.height, 4);
      expect(result.rgba.length, 6 * 4 * 4);
    });

    test('rotation 90° swaps dimensions', () {
      final nv21 = _createNv21(width: 6, height: 4, y: 128, u: 128, v: 128);
      final result = nv21ToRgba(
        nv21Bytes: nv21,
        width: 6,
        height: 4,
        rotationDegrees: 90,
      );

      expect(result.width, 4); // H becomes W
      expect(result.height, 6); // W becomes H
      expect(result.rgba.length, 4 * 6 * 4);
    });

    test('rotation 180° preserves dimensions', () {
      final nv21 = _createNv21(width: 6, height: 4, y: 128, u: 128, v: 128);
      final result = nv21ToRgba(
        nv21Bytes: nv21,
        width: 6,
        height: 4,
        rotationDegrees: 180,
      );

      expect(result.width, 6);
      expect(result.height, 4);
    });

    test('rotation 270° swaps dimensions', () {
      final nv21 = _createNv21(width: 6, height: 4, y: 128, u: 128, v: 128);
      final result = nv21ToRgba(
        nv21Bytes: nv21,
        width: 6,
        height: 4,
        rotationDegrees: 270,
      );

      expect(result.width, 4);
      expect(result.height, 6);
    });

    test('rotation 90° maps pixels correctly', () {
      // 4x2 image with position-encoded Y, neutral chroma
      // Input pixel (3,0) → has Y = 3 → should map to output (1,3) for 90° CW
      // Output is 2x4 (H×W)
      final nv21 = _createPositionNv21(width: 4, height: 2);
      final result = nv21ToRgba(
        nv21Bytes: nv21,
        width: 4,
        height: 2,
        rotationDegrees: 90,
      );

      // Input (0,0) Y=0 → output (H-1-0, 0) = (1, 0) in outW=2
      // Output idx = 0*2 + 1 = 1 → byte offset = 4
      // With neutral chroma, R≈G≈B≈Y
      final topLeftR = result.rgba[1 * 4]; // output (1,0)
      expect(topLeftR, lessThan(5)); // Y was 0

      // Input (3,0) Y=3 → output (H-1-0, 3) = (1, 3) in outW=2
      // Output idx = 3*2 + 1 = 7 → byte offset = 28
      final pixel30R = result.rgba[7 * 4];
      expect(pixel30R, lessThan(10)); // Y was 3
    });

    test('rotation 180° reverses pixel order', () {
      // With position-encoded Y:
      // Input (0,0) Y=0 → output (W-1, H-1) = (3, 1) for 4x2 image
      final nv21 = _createPositionNv21(width: 4, height: 2);
      final result = nv21ToRgba(
        nv21Bytes: nv21,
        width: 4,
        height: 2,
        rotationDegrees: 180,
      );

      // Input (0,0) Y=0 → output (3,1) in 4×2
      // Output idx = 1*4 + 3 = 7 → byte offset = 28
      expect(result.rgba[7 * 4], lessThan(5)); // R ≈ Y = 0
    });

    test('returns empty for empty input', () {
      final result = nv21ToRgba(
        nv21Bytes: Uint8List(0),
        width: 0,
        height: 0,
      );

      expect(result.rgba.length, 0);
      expect(result.width, 0);
      expect(result.height, 0);
    });

    test('returns empty for undersized buffer', () {
      // 4x4 needs 4*4 + 4*2 = 24 bytes, provide only 10
      final result = nv21ToRgba(
        nv21Bytes: Uint8List(10),
        width: 4,
        height: 4,
      );

      expect(result.rgba.length, 0);
    });

    test('alpha channel is always 255', () {
      final nv21 = _createNv21(width: 4, height: 4, y: 100, u: 100, v: 200);
      final result = nv21ToRgba(nv21Bytes: nv21, width: 4, height: 4);

      // Check alpha for every pixel
      for (var i = 3; i < result.rgba.length; i += 4) {
        expect(result.rgba[i], 255);
      }
    });

    test('mid-gray NV21 produces mid-gray RGBA', () {
      // Y=128, U=128, V=128 → R≈128, G≈128, B≈128
      final nv21 = _createNv21(width: 4, height: 4, y: 128, u: 128, v: 128);
      final result = nv21ToRgba(nv21Bytes: nv21, width: 4, height: 4);

      expect(result.rgba[0], closeTo(128, 3)); // R
      expect(result.rgba[1], closeTo(128, 3)); // G
      expect(result.rgba[2], closeTo(128, 3)); // B
    });
  });
}
