import 'dart:typed_data';

import 'package:eid_reader/core/utils/nv21_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a minimal NV21 buffer with all Y pixels set to [yValue].
Uint8List _createUniformNv21({
  required int width,
  required int height,
  required int yValue,
}) {
  final size = width * height + width * (height ~/ 2);
  final buffer = Uint8List(size);
  for (int i = 0; i < width * height; i++) {
    buffer[i] = yValue;
  }
  return buffer;
}

/// Creates an NV21 buffer with alternating bright/dark rows to simulate edges.
Uint8List _createEdgyNv21({
  required int width,
  required int height,
  required int brightValue,
  required int darkValue,
}) {
  final size = width * height + width * (height ~/ 2);
  final buffer = Uint8List(size);
  for (int y = 0; y < height; y++) {
    final val = y.isEven ? brightValue : darkValue;
    for (int x = 0; x < width; x++) {
      buffer[y * width + x] = val;
    }
  }
  return buffer;
}

/// Creates an NV21 buffer with varied edges (gradient + noise).
/// Produces varying Laplacian values → non-zero variance = "sharp".
Uint8List _createSharpNv21({
  required int width,
  required int height,
}) {
  final size = width * height + width * (height ~/ 2);
  final buffer = Uint8List(size);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Mix gradient and position-dependent variation for varied edges
      buffer[y * width + x] = ((x * 13 + y * 7 + x * y) % 200 + 30).clamp(0, 255);
    }
  }
  return buffer;
}

void main() {
  group('computeNv21BlurScore', () {
    test('uniform image (all same Y) returns 0.0 (no edges = blurry)', () {
      final nv21 = _createUniformNv21(width: 10, height: 10, yValue: 128);
      expect(computeNv21BlurScore(nv21, 10, 10), 0.0);
    });

    test('sharp image with varied edges returns high score', () {
      final nv21 = _createSharpNv21(width: 20, height: 20);
      final score = computeNv21BlurScore(nv21, 20, 20);
      expect(score, greaterThan(50));
    });

    test('sharp image scores higher than uniform image', () {
      final sharp = _createSharpNv21(width: 20, height: 20);
      final uniform = _createUniformNv21(width: 20, height: 20, yValue: 128);
      final sharpScore = computeNv21BlurScore(sharp, 20, 20);
      final uniformScore = computeNv21BlurScore(uniform, 20, 20);
      expect(sharpScore, greaterThan(uniformScore));
    });

    test('empty buffer returns 0.0', () {
      expect(computeNv21BlurScore(Uint8List(0), 10, 10), 0.0);
    });

    test('too small image returns 0.0', () {
      final nv21 = _createUniformNv21(width: 2, height: 2, yValue: 128);
      expect(computeNv21BlurScore(nv21, 2, 2), 0.0);
    });

    test('step parameter affects precision but detects sharpness', () {
      final nv21 = _createSharpNv21(width: 40, height: 40);
      final score1 = computeNv21BlurScore(nv21, 40, 40, step: 1);
      final score2 = computeNv21BlurScore(nv21, 40, 40, step: 2);
      // Both should detect edges, step=2 is faster but slightly less precise
      expect(score1, greaterThan(10));
      expect(score2, greaterThan(10));
    });
  });

  group('computeNv21ExposureMetrics', () {
    test('all-black returns meanBrightness 0 and darkRatio 1.0', () {
      final nv21 = _createUniformNv21(width: 4, height: 4, yValue: 0);
      final metrics = computeNv21ExposureMetrics(nv21, 4, 4);
      expect(metrics.meanBrightness, 0.0);
      expect(metrics.darkRatio, 1.0);
    });

    test('all-white returns meanBrightness 255 and darkRatio 0.0', () {
      final nv21 = _createUniformNv21(width: 4, height: 4, yValue: 255);
      final metrics = computeNv21ExposureMetrics(nv21, 4, 4);
      expect(metrics.meanBrightness, 255.0);
      expect(metrics.darkRatio, 0.0);
    });

    test('mid-gray returns correct brightness', () {
      final nv21 = _createUniformNv21(width: 4, height: 4, yValue: 128);
      final metrics = computeNv21ExposureMetrics(nv21, 4, 4);
      expect(metrics.meanBrightness, 128.0);
      expect(metrics.darkRatio, 0.0); // 128 > 40 default threshold
    });

    test('dim image (Y=30) detected as dark', () {
      final nv21 = _createUniformNv21(width: 4, height: 4, yValue: 30);
      final metrics = computeNv21ExposureMetrics(nv21, 4, 4);
      expect(metrics.meanBrightness, 30.0);
      expect(metrics.darkRatio, 1.0); // all pixels below 40
    });

    test('custom dark threshold works', () {
      final nv21 = _createUniformNv21(width: 4, height: 4, yValue: 100);
      final metrics =
          computeNv21ExposureMetrics(nv21, 4, 4, darkThreshold: 120);
      expect(metrics.darkRatio, 1.0); // all below 120
    });

    test('empty buffer returns zeros', () {
      final metrics = computeNv21ExposureMetrics(Uint8List(0), 4, 4);
      expect(metrics.meanBrightness, 0.0);
      expect(metrics.darkRatio, 0.0);
    });
  });

  group('computeNv21CompositeScore', () {
    test('good quality frame (sharp, well-lit, no glare) has low score', () {
      final nv21 = _createSharpNv21(width: 20, height: 20);
      final score = computeNv21CompositeScore(nv21, 20, 20);
      expect(score, lessThan(0.5));
    });

    test('blurry frame (uniform Y) has higher score', () {
      final nv21 = _createUniformNv21(width: 20, height: 20, yValue: 128);
      final score = computeNv21CompositeScore(nv21, 20, 20);
      // Uniform = blurry → high blur penalty
      expect(score, greaterThan(0.3));
    });

    test('dark frame has high score', () {
      final nv21 = _createUniformNv21(width: 20, height: 20, yValue: 20);
      final score = computeNv21CompositeScore(nv21, 20, 20);
      expect(score, greaterThan(0.5));
    });

    test('glaring frame (all white) has high score', () {
      final nv21 = _createUniformNv21(width: 20, height: 20, yValue: 255);
      final score = computeNv21CompositeScore(nv21, 20, 20);
      // All over-exposed → high glare + blur penalty (uniform)
      expect(score, greaterThan(0.5));
    });
  });

  group('downsampleNv21x2', () {
    test('halves dimensions', () {
      final nv21 = _createUniformNv21(width: 8, height: 8, yValue: 128);
      final result = downsampleNv21x2(nv21, 8, 8);
      expect(result, isNotNull);
      expect(result!.width, 4);
      expect(result.height, 4);
    });

    test('output has correct NV21 buffer size', () {
      final nv21 = _createUniformNv21(width: 8, height: 8, yValue: 128);
      final result = downsampleNv21x2(nv21, 8, 8)!;
      // NV21 size = w*h + w*(h/2) = 4*4 + 4*2 = 24
      expect(result.bytes.length, 24);
    });

    test('averages Y values in 2x2 blocks', () {
      // Create 4x4 with known Y values
      const size = 4 * 4 + 4 * 2;
      final nv21 = Uint8List(size);
      // Top-left 2x2 block: 100, 200, 100, 200 → avg = 150
      nv21[0] = 100;
      nv21[1] = 200;
      nv21[4] = 100;
      nv21[5] = 200;

      final result = downsampleNv21x2(nv21, 4, 4)!;
      expect(result.bytes[0], 150); // Average of 100, 200, 100, 200
    });

    test('returns null for odd dimensions', () {
      final nv21 = _createUniformNv21(width: 7, height: 8, yValue: 128);
      expect(downsampleNv21x2(nv21, 7, 8), isNull);
    });

    test('returns null for too small dimensions', () {
      final nv21 = _createUniformNv21(width: 2, height: 2, yValue: 128);
      expect(downsampleNv21x2(nv21, 2, 2), isNull);
    });

    test('returns null for undersized buffer', () {
      expect(downsampleNv21x2(Uint8List(10), 8, 8), isNull);
    });

    test('handles larger dimensions correctly', () {
      final nv21 = _createUniformNv21(width: 100, height: 100, yValue: 200);
      final result = downsampleNv21x2(nv21, 100, 100)!;
      expect(result.width, 50);
      expect(result.height, 50);
      expect(result.bytes.length, 50 * 50 + 50 * 25);
      // Uniform input → downsampled Y should still be 200
      expect(result.bytes[0], 200);
    });
  });

  group('nv21ToRgbaRoi', () {
    /// Creates NV21 with neutral chroma (U=128, V=128) and Y = yValue.
    Uint8List createNeutralNv21(int w, int h, int yValue) {
      final ySize = w * h;
      final uvSize = w * (h ~/ 2);
      final buf = Uint8List(ySize + uvSize);
      for (int i = 0; i < ySize; i++) {
        buf[i] = yValue;
      }
      for (int i = 0; i < uvSize; i += 2) {
        buf[ySize + i] = 128; // V
        buf[ySize + i + 1] = 128; // U
      }
      return buf;
    }

    test('extracts ROI with correct dimensions (no rotation)', () {
      final nv21 = createNeutralNv21(10, 10, 128);
      final result = nv21ToRgbaRoi(
        nv21Bytes: nv21,
        width: 10,
        height: 10,
        roiX: 2,
        roiY: 2,
        roiW: 4,
        roiH: 4,
        rotationDegrees: 0,
      );
      expect(result.width, 4);
      expect(result.height, 4);
      expect(result.rgba.length, 4 * 4 * 4);
    });

    test('ROI pixel values match full-image conversion', () {
      final nv21 = createNeutralNv21(8, 8, 200);
      final roiResult = nv21ToRgbaRoi(
        nv21Bytes: nv21,
        width: 8,
        height: 8,
        roiX: 0,
        roiY: 0,
        roiW: 4,
        roiH: 4,
        rotationDegrees: 0,
      );
      final fullResult = nv21ToRgba(
        nv21Bytes: nv21,
        width: 8,
        height: 8,
        rotationDegrees: 0,
      );

      // First pixel of ROI should match first pixel of full image
      for (int i = 0; i < 4; i++) {
        expect(roiResult.rgba[i], fullResult.rgba[i]);
      }
    });

    test('ROI with 90° rotation swaps dimensions', () {
      final nv21 = createNeutralNv21(10, 8, 128);
      final result = nv21ToRgbaRoi(
        nv21Bytes: nv21,
        width: 10,
        height: 8,
        roiX: 2,
        roiY: 2,
        roiW: 4,
        roiH: 4,
        rotationDegrees: 90,
      );
      expect(result.width, 4); // roiH
      expect(result.height, 4); // roiW
    });

    test('clamps ROI to buffer bounds', () {
      final nv21 = createNeutralNv21(8, 8, 128);
      final result = nv21ToRgbaRoi(
        nv21Bytes: nv21,
        width: 8,
        height: 8,
        roiX: 6,
        roiY: 6,
        roiW: 10,
        roiH: 10,
        rotationDegrees: 0,
      );
      // Clamped to 8-6=2 width, 8-6=2 height
      expect(result.width, 2);
      expect(result.height, 2);
    });

    test('returns empty for zero-size ROI', () {
      final nv21 = createNeutralNv21(8, 8, 128);
      final result = nv21ToRgbaRoi(
        nv21Bytes: nv21,
        width: 8,
        height: 8,
        roiX: 0,
        roiY: 0,
        roiW: 0,
        roiH: 0,
        rotationDegrees: 0,
      );
      expect(result.rgba.length, 0);
    });

    test('returns empty for empty input', () {
      final result = nv21ToRgbaRoi(
        nv21Bytes: Uint8List(0),
        width: 0,
        height: 0,
        roiX: 0,
        roiY: 0,
        roiW: 4,
        roiH: 4,
        rotationDegrees: 0,
      );
      expect(result.rgba.length, 0);
    });

    test('alpha channel is always 255', () {
      final nv21 = createNeutralNv21(8, 8, 100);
      final result = nv21ToRgbaRoi(
        nv21Bytes: nv21,
        width: 8,
        height: 8,
        roiX: 0,
        roiY: 0,
        roiW: 4,
        roiH: 4,
        rotationDegrees: 0,
      );
      for (var i = 3; i < result.rgba.length; i += 4) {
        expect(result.rgba[i], 255);
      }
    });
  });
}
