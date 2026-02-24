import 'dart:typed_data';

import 'package:eid_reader/core/services/image_quality_analyzer.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/image_quality_metrics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Creates a synthetic test image encoded as PNG bytes.
Uint8List _createTestImage({
  int width = 100,
  int height = 100,
  int Function(int x, int y)? pixelValue,
}) {
  final image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final v = pixelValue?.call(x, y) ?? 128;
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// Creates a colorful image with high saturation variance.
Uint8List _createRainbowImage({int width = 100, int height = 100}) {
  final image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Create rainbow-like pattern
      final r = ((x * 255) ~/ width);
      final g = ((y * 255) ~/ height);
      final b = (((x + y) * 127) ~/ (width + height));
      image.setPixelRgb(x, y, r, g, b);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  late DefaultImageQualityAnalyzer analyzer;

  setUp(() {
    analyzer = DefaultImageQualityAnalyzer();
  });

  group('ImageQualityAnalyzer', () {
    test('sharp image has high blur score', () {
      // High-frequency pattern (checkerboard) = sharp
      final bytes = _createTestImage(
        pixelValue: (x, y) => ((x + y) % 2 == 0) ? 0 : 255,
      );
      final metrics = analyzer.analyze(bytes);
      expect(metrics.blurScore, greaterThan(100));
    });

    test('uniform image has low blur score', () {
      // Uniform gray = no edges = blurry
      final bytes = _createTestImage(pixelValue: (x, y) => 128);
      final metrics = analyzer.analyze(bytes);
      expect(metrics.blurScore, lessThan(1));
    });

    test('bright image has high glare ratio', () {
      // All pixels at 250 luminance
      final bytes = _createTestImage(pixelValue: (x, y) => 250);
      final metrics = analyzer.analyze(bytes);
      expect(metrics.glareRatio, greaterThan(0.9));
    });

    test('dark image has low glare ratio', () {
      // All pixels at 100 luminance
      final bytes = _createTestImage(pixelValue: (x, y) => 100);
      final metrics = analyzer.analyze(bytes);
      expect(metrics.glareRatio, equals(0));
    });

    test('mixed brightness has moderate glare ratio', () {
      // Half bright, half dark
      final bytes = _createTestImage(
        pixelValue: (x, y) => x < 50 ? 250 : 100,
      );
      final metrics = analyzer.analyze(bytes);
      expect(metrics.glareRatio, closeTo(0.5, 0.05));
    });

    test('uniform gray has low saturation std dev', () {
      final bytes = _createTestImage(pixelValue: (x, y) => 128);
      final metrics = analyzer.analyze(bytes);
      expect(metrics.saturationStdDev, lessThan(0.01));
    });

    test('rainbow image has high saturation std dev', () {
      final bytes = _createRainbowImage();
      final metrics = analyzer.analyze(bytes);
      expect(metrics.saturationStdDev, greaterThan(0.1));
    });

    test('uniform image has zero contrast', () {
      final bytes = _createTestImage(pixelValue: (x, y) => 128);
      final metrics = analyzer.analyze(bytes);
      expect(metrics.contrastRatio, equals(0));
    });

    test('high contrast image has high contrast ratio', () {
      // Black and white
      final bytes = _createTestImage(
        pixelValue: (x, y) => x < 50 ? 0 : 255,
      );
      final metrics = analyzer.analyze(bytes);
      expect(metrics.contrastRatio, equals(1.0));
    });

    test('overall score is between 0 and 1', () {
      final bytes = _createTestImage(
        pixelValue: (x, y) => ((x + y) % 2 == 0) ? 50 : 200,
      );
      final metrics = analyzer.analyze(bytes);
      expect(metrics.overallScore, greaterThanOrEqualTo(0));
      expect(metrics.overallScore, lessThanOrEqualTo(1));
    });

    test('good quality image produces good quality level', () {
      // Sharp, no glare, good contrast
      final bytes = _createTestImage(
        pixelValue: (x, y) => ((x * 7 + y * 13) % 200) + 28,
      );
      final metrics = analyzer.analyze(bytes);
      expect(metrics.qualityLevel, isIn([
        ImageQualityLevel.good,
        ImageQualityLevel.acceptable,
      ]));
    });

    test('issues list identifies blur', () {
      final bytes = _createTestImage(pixelValue: (x, y) => 128);
      final metrics = analyzer.analyze(bytes);
      expect(metrics.issues, contains('Image is blurry'));
    });

    test('issues list identifies glare', () {
      final bytes = _createTestImage(pixelValue: (x, y) => 250);
      final metrics = analyzer.analyze(bytes);
      expect(
        metrics.issues,
        anyElement(contains('glare')),
      );
    });
  });

  group('ImageQualityAnalyzer.analyzeFromPixels', () {
    test('uniform gray pixels have low blur and zero contrast', () {
      const w = 100, h = 100;
      final rgba = ByteData(w * h * 4);
      for (int i = 0; i < w * h; i++) {
        rgba.setUint8(i * 4, 128);
        rgba.setUint8(i * 4 + 1, 128);
        rgba.setUint8(i * 4 + 2, 128);
        rgba.setUint8(i * 4 + 3, 255);
      }
      final metrics = analyzer.analyzeFromPixels(rgba, w, h);
      expect(metrics.blurScore, lessThan(1));
      expect(metrics.contrastRatio, equals(0));
      expect(metrics.saturationStdDev, lessThan(0.01));
    });

    test('bright pixels have high glare ratio', () {
      const w = 50, h = 50;
      final rgba = ByteData(w * h * 4);
      for (int i = 0; i < w * h; i++) {
        rgba.setUint8(i * 4, 250);
        rgba.setUint8(i * 4 + 1, 250);
        rgba.setUint8(i * 4 + 2, 250);
        rgba.setUint8(i * 4 + 3, 255);
      }
      final metrics = analyzer.analyzeFromPixels(rgba, w, h);
      expect(metrics.glareRatio, greaterThan(0.9));
    });

    test('checkerboard pixels have high blur score', () {
      const w = 100, h = 100;
      final rgba = ByteData(w * h * 4);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final v = ((x + y) % 2 == 0) ? 0 : 255;
          final off = (y * w + x) * 4;
          rgba.setUint8(off, v);
          rgba.setUint8(off + 1, v);
          rgba.setUint8(off + 2, v);
          rgba.setUint8(off + 3, 255);
        }
      }
      final metrics = analyzer.analyzeFromPixels(rgba, w, h);
      expect(metrics.blurScore, greaterThan(100));
    });

    test('black-and-white pixels have contrast ratio 1.0', () {
      const w = 100, h = 100;
      final rgba = ByteData(w * h * 4);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final v = x < 50 ? 0 : 255;
          final off = (y * w + x) * 4;
          rgba.setUint8(off, v);
          rgba.setUint8(off + 1, v);
          rgba.setUint8(off + 2, v);
          rgba.setUint8(off + 3, 255);
        }
      }
      final metrics = analyzer.analyzeFromPixels(rgba, w, h);
      expect(metrics.contrastRatio, equals(1.0));
    });

    test('overall score is between 0 and 1', () {
      const w = 50, h = 50;
      final rgba = ByteData(w * h * 4);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final v = ((x + y) % 2 == 0) ? 50 : 200;
          final off = (y * w + x) * 4;
          rgba.setUint8(off, v);
          rgba.setUint8(off + 1, v);
          rgba.setUint8(off + 2, v);
          rgba.setUint8(off + 3, 255);
        }
      }
      final metrics = analyzer.analyzeFromPixels(rgba, w, h);
      expect(metrics.overallScore, greaterThanOrEqualTo(0));
      expect(metrics.overallScore, lessThanOrEqualTo(1));
    });

    test('empty image returns zero scores', () {
      final rgba = ByteData(0);
      final metrics = analyzer.analyzeFromPixels(rgba, 0, 0);
      expect(metrics.overallScore, equals(0));
      expect(metrics.issues, contains('Empty image'));
    });
  });
}
