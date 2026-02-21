import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../features/passport_reader/domain/entities/image_quality_metrics.dart';

/// Analyzes image quality of a face region for hologram/glare detection.
///
/// Uses purely computational metrics (no ML model):
/// - Laplacian variance for blur detection
/// - Over-exposed pixel ratio for glare detection
/// - Saturation std dev for hologram rainbow pattern detection
/// - Michelson contrast ratio
abstract class ImageQualityAnalyzer {
  /// Analyzes the quality of a face image.
  ImageQualityMetrics analyze(Uint8List imageBytes);
}

/// Default implementation using the `image` package.
class DefaultImageQualityAnalyzer implements ImageQualityAnalyzer {
  @override
  ImageQualityMetrics analyze(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return const ImageQualityMetrics(
        blurScore: 0,
        glareRatio: 1,
        saturationStdDev: 0,
        contrastRatio: 0,
        overallScore: 0,
        issues: ['Failed to decode image'],
      );
    }

    // Compute saturation before grayscale conversion (grayscale modifies in-place)
    final saturationStdDev = _calculateSaturationStdDev(decoded);

    final grayscale = img.grayscale(decoded);

    final blurScore = _calculateBlurScore(grayscale);
    final glareRatio = _calculateGlareRatio(grayscale);
    final contrastRatio = _calculateContrastRatio(grayscale);

    final issues = <String>[];
    if (blurScore < 50) issues.add('Image is blurry');
    if (glareRatio > 0.15) issues.add('Severe glare detected (possible hologram)');
    if (glareRatio > 0.05 && glareRatio <= 0.15) issues.add('Moderate glare detected');
    if (saturationStdDev > 0.25) {
      issues.add('Rainbow pattern detected (possible hologram)');
    }
    if (contrastRatio < 0.15) issues.add('Low contrast');

    final overallScore = _calculateOverallScore(
      blurScore: blurScore,
      glareRatio: glareRatio,
      saturationStdDev: saturationStdDev,
      contrastRatio: contrastRatio,
    );

    return ImageQualityMetrics(
      blurScore: blurScore,
      glareRatio: glareRatio,
      saturationStdDev: saturationStdDev,
      contrastRatio: contrastRatio,
      overallScore: overallScore,
      issues: issues,
    );
  }

  /// Calculates Laplacian variance as a measure of sharpness.
  ///
  /// Applies a 3x3 Laplacian kernel to the grayscale image and
  /// computes the variance of the output. Higher = sharper.
  double _calculateBlurScore(img.Image grayscale) {
    final width = grayscale.width;
    final height = grayscale.height;

    if (width < 3 || height < 3) return 0;

    // Laplacian kernel: [0, 1, 0; 1, -4, 1; 0, 1, 0]
    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final center = grayscale.getPixel(x, y).r.toDouble();
        final top = grayscale.getPixel(x, y - 1).r.toDouble();
        final bottom = grayscale.getPixel(x, y + 1).r.toDouble();
        final left = grayscale.getPixel(x - 1, y).r.toDouble();
        final right = grayscale.getPixel(x + 1, y).r.toDouble();

        final laplacian = top + bottom + left + right - 4 * center;
        sum += laplacian;
        sumSq += laplacian * laplacian;
        count++;
      }
    }

    if (count == 0) return 0;

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return variance.abs();
  }

  /// Calculates the ratio of over-exposed pixels (luminance > 240).
  double _calculateGlareRatio(img.Image grayscale) {
    final totalPixels = grayscale.width * grayscale.height;
    if (totalPixels == 0) return 0;

    int overExposed = 0;
    for (final pixel in grayscale) {
      if (pixel.r > 240) overExposed++;
    }

    return overExposed / totalPixels;
  }

  /// Calculates the standard deviation of saturation in HSV color space.
  ///
  /// High std dev indicates varied saturation, which can signal
  /// hologram rainbow interference patterns.
  double _calculateSaturationStdDev(img.Image image) {
    final totalPixels = image.width * image.height;
    if (totalPixels == 0) return 0;

    final saturations = Float64List(totalPixels);
    int idx = 0;

    for (final pixel in image) {
      final r = pixel.r.toDouble() / 255.0;
      final g = pixel.g.toDouble() / 255.0;
      final b = pixel.b.toDouble() / 255.0;

      final maxC = max(r, max(g, b));
      final minC = min(r, min(g, b));

      // HSV saturation
      final saturation = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
      saturations[idx++] = saturation;
    }

    // Calculate standard deviation
    double sum = 0;
    for (int i = 0; i < totalPixels; i++) {
      sum += saturations[i];
    }
    final mean = sum / totalPixels;

    double varianceSum = 0;
    for (int i = 0; i < totalPixels; i++) {
      final diff = saturations[i] - mean;
      varianceSum += diff * diff;
    }

    return sqrt(varianceSum / totalPixels);
  }

  /// Calculates Michelson contrast: (Lmax - Lmin) / (Lmax + Lmin).
  double _calculateContrastRatio(img.Image grayscale) {
    double lMin = 255;
    double lMax = 0;

    for (final pixel in grayscale) {
      final lum = pixel.r.toDouble();
      if (lum < lMin) lMin = lum;
      if (lum > lMax) lMax = lum;
    }

    final denominator = lMax + lMin;
    if (denominator == 0) return 0;

    return (lMax - lMin) / denominator;
  }

  /// Calculates weighted overall quality score (0.0 - 1.0).
  double _calculateOverallScore({
    required double blurScore,
    required double glareRatio,
    required double saturationStdDev,
    required double contrastRatio,
  }) {
    // Normalize each metric to 0.0-1.0 (higher = better)
    final blurNorm = (blurScore / 200).clamp(0.0, 1.0);
    final glareNorm = (1.0 - (glareRatio / 0.3)).clamp(0.0, 1.0);
    final satNorm = (1.0 - (saturationStdDev / 0.5)).clamp(0.0, 1.0);
    final contrastNorm = (contrastRatio / 0.6).clamp(0.0, 1.0);

    // Weighted average: blur 35%, glare 30%, saturation 15%, contrast 20%
    return blurNorm * 0.35 +
        glareNorm * 0.30 +
        satNorm * 0.15 +
        contrastNorm * 0.20;
  }
}
