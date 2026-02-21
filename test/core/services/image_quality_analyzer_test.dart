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
}
