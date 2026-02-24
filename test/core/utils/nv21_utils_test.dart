import 'dart:typed_data';

import 'package:eid_reader/core/utils/nv21_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a synthetic NV21 buffer where each Y pixel value encodes
/// its (x, y) position for easy verification.
Uint8List _createNv21({required int w, required int h}) {
  final size = w * h * 3 ~/ 2;
  final buf = Uint8List(size);

  // Y plane: value = (x + y * w) % 256
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      buf[y * w + x] = (x + y * w) % 256;
    }
  }

  // VU plane: value = (vuRow * w + col) % 256
  final yPlaneSize = w * h;
  final vuHeight = h ~/ 2;
  for (var vuRow = 0; vuRow < vuHeight; vuRow++) {
    for (var col = 0; col < w; col++) {
      buf[yPlaneSize + vuRow * w + col] = (vuRow * w + col) % 256;
    }
  }

  return buf;
}

void main() {
  group('cropNv21ForMrz', () {
    group('buffer size', () {
      test('cropped buffer has correct NV21 size for rotation 0', () {
        final nv21 = _createNv21(w: 100, h: 100);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 100,
          height: 100,
          rotationDegrees: 0,
          cropFraction: 0.35,
        );
        // cropH = evenFloor(35) = 34
        expect(result.width, 100);
        expect(result.height, 34);
        expect(result.bytes.length, 100 * 34 * 3 ~/ 2);
      });

      test('cropped buffer has correct NV21 size for rotation 90', () {
        final nv21 = _createNv21(w: 100, h: 80);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 100,
          height: 80,
          rotationDegrees: 90,
          cropFraction: 0.35,
        );
        // cropW = evenFloor(35) = 34
        expect(result.width, 34);
        expect(result.height, 80);
        expect(result.bytes.length, 34 * 80 * 3 ~/ 2);
      });

      test('cropped buffer has correct NV21 size for rotation 180', () {
        final nv21 = _createNv21(w: 100, h: 100);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 100,
          height: 100,
          rotationDegrees: 180,
          cropFraction: 0.35,
        );
        // cropH = evenFloor(35) = 34
        expect(result.width, 100);
        expect(result.height, 34);
        expect(result.bytes.length, 100 * 34 * 3 ~/ 2);
      });

      test('cropped buffer has correct NV21 size for rotation 270', () {
        final nv21 = _createNv21(w: 100, h: 80);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 100,
          height: 80,
          rotationDegrees: 270,
          cropFraction: 0.35,
        );
        // cropW = evenFloor(35) = 34
        expect(result.width, 34);
        expect(result.height, 80);
        expect(result.bytes.length, 34 * 80 * 3 ~/ 2);
      });
    });

    group('pixel correctness', () {
      test('rotation 0 crops bottom rows', () {
        final nv21 = _createNv21(w: 10, h: 10);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 10,
          height: 10,
          rotationDegrees: 0,
          cropFraction: 0.5,
        );
        // cropH = evenFloor(5) = 4, startY = 10 - 4 = 6
        expect(result.height, 4);
        // First Y pixel should be at original (0, 6) = (0 + 6*10) % 256 = 60
        expect(result.bytes[0], 60);
        // Pixel at (5, 6) = (5 + 6*10) % 256 = 65
        expect(result.bytes[5], 65);
      });

      test('rotation 180 crops top rows', () {
        final nv21 = _createNv21(w: 10, h: 10);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 10,
          height: 10,
          rotationDegrees: 180,
          cropFraction: 0.5,
        );
        // cropH = evenFloor(5) = 4, startY = 0
        expect(result.height, 4);
        // First Y pixel at original (0, 0) = 0
        expect(result.bytes[0], 0);
      });

      test('rotation 90 crops right columns', () {
        final nv21 = _createNv21(w: 10, h: 10);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 10,
          height: 10,
          rotationDegrees: 90,
          cropFraction: 0.5,
        );
        // cropW = evenFloor(5) = 4, startX = 10 - 4 = 6
        expect(result.width, 4);
        // First Y pixel at original (6, 0) = 6
        expect(result.bytes[0], 6);
        // Second pixel at original (7, 0) = 7
        expect(result.bytes[1], 7);
      });

      test('rotation 270 crops left columns', () {
        final nv21 = _createNv21(w: 10, h: 10);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 10,
          height: 10,
          rotationDegrees: 270,
          cropFraction: 0.5,
        );
        // cropW = evenFloor(5) = 4, startX = 0
        expect(result.width, 4);
        // First Y pixel at original (0, 0) = 0
        expect(result.bytes[0], 0);
        // Pixel at (1, 0) = 1
        expect(result.bytes[1], 1);
      });
    });

    group('even alignment', () {
      test('odd crop dimension is rounded to even', () {
        final nv21 = _createNv21(w: 100, h: 100);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 100,
          height: 100,
          rotationDegrees: 0,
          cropFraction: 0.33, // 33 → even floor → 32
        );
        expect(result.height % 2, 0);
        expect(result.height, 32);
      });

      test('column crop width is even', () {
        final nv21 = _createNv21(w: 100, h: 80);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 100,
          height: 80,
          rotationDegrees: 90,
          cropFraction: 0.33,
        );
        expect(result.width % 2, 0);
        expect(result.width, 32);
      });
    });

    group('edge cases', () {
      test('empty buffer returns unchanged', () {
        final result = cropNv21ForMrz(
          nv21Bytes: Uint8List(0),
          width: 0,
          height: 0,
          rotationDegrees: 0,
        );
        expect(result.bytes.length, 0);
        expect(result.width, 0);
        expect(result.height, 0);
      });

      test('unknown rotation returns unchanged', () {
        final nv21 = _createNv21(w: 10, h: 10);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 10,
          height: 10,
          rotationDegrees: 45,
        );
        expect(result.bytes.length, nv21.length);
        expect(result.width, 10);
        expect(result.height, 10);
      });

      test('small image with crop fraction producing < 2 rows', () {
        final nv21 = _createNv21(w: 4, h: 4);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 4,
          height: 4,
          rotationDegrees: 0,
          cropFraction: 0.1, // 0.4 → evenFloor → 2 (minimum)
        );
        expect(result.height, 2);
        expect(result.bytes.length, 4 * 2 * 3 ~/ 2);
      });

      test('crop fraction 1.0 returns original dimensions', () {
        final nv21 = _createNv21(w: 10, h: 10);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 10,
          height: 10,
          rotationDegrees: 0,
          cropFraction: 1.0,
        );
        // cropH = evenFloor(10) = 10, which equals h → returns original
        expect(result.width, 10);
        expect(result.height, 10);
      });
    });

    group('realistic dimensions', () {
      test('1920x1080 with rotation 90 and default fraction', () {
        // Don't create full buffer (too large for test), just verify dimensions
        const w = 1920, h = 1080;
        final nv21 = Uint8List(w * h * 3 ~/ 2);
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: w,
          height: h,
          rotationDegrees: 90,
        );
        // cropW = evenFloor(1920 * 0.40 = 768) = 768
        expect(result.width, 768);
        expect(result.height, 1080);
        expect(result.bytes.length, 768 * 1080 * 3 ~/ 2);
      });
    });

    group('srcStride handling', () {
      test('handles stride with padding (stride > width)', () {
        // Simulate a 10x4 image with stride=12 (2 bytes padding per row)
        const w = 10, h = 4, stride = 12;
        // NV21 buffer: Y = stride*h, VU = stride*(h/2)
        const bufSize = stride * h + stride * (h ~/ 2);
        final nv21 = Uint8List(bufSize);

        // Fill Y plane with known values (using stride layout)
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            nv21[y * stride + x] = (x + y * w) % 256;
          }
          // Padding bytes at x=10,11 remain 0
        }

        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: w,
          height: h,
          rotationDegrees: 0,
          srcStride: stride,
          cropFraction: 0.5,
        );
        // cropH = evenFloor(2) = 2, startY = 4 - 2 = 2
        expect(result.height, 2);
        expect(result.width, 10);
        // First pixel should be from row 2: (0 + 2*10) % 256 = 20
        expect(result.bytes[0], 20);
        // Pixel (5,2): (5 + 2*10) % 256 = 25
        expect(result.bytes[5], 25);
      });

      test('skips crop when buffer is too small', () {
        // Buffer smaller than expected NV21 size
        final nv21 = Uint8List(100); // Too small for 10x10
        final result = cropNv21ForMrz(
          nv21Bytes: nv21,
          width: 10,
          height: 10,
          rotationDegrees: 0,
        );
        // Should return original (uncropped) because buffer is too small
        expect(result.bytes.length, 100);
        expect(result.width, 10);
        expect(result.height, 10);
      });
    });
  });
}
