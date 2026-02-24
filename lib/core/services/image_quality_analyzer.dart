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
  /// Analyzes the quality of a face image from encoded bytes (JPEG/PNG).
  ImageQualityMetrics analyze(Uint8List imageBytes);

  /// Analyzes the quality of a face image from raw RGBA pixel data.
  ///
  /// This avoids a redundant decode when pixel data is already available
  /// (e.g. from dart:ui's toByteData(format: rawRgba)).
  ImageQualityMetrics analyzeFromPixels(
      ByteData rgbaPixels, int width, int height);
}

/// Default implementation using the `image` package for encoded bytes,
/// and direct RGBA pixel access for pre-decoded data.
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

    return _buildMetrics(
      blurScore: blurScore,
      glareRatio: glareRatio,
      saturationStdDev: saturationStdDev,
      contrastRatio: contrastRatio,
    );
  }

  @override
  ImageQualityMetrics analyzeFromPixels(
      ByteData rgbaPixels, int width, int height) {
    final totalPixels = width * height;
    if (totalPixels == 0) {
      return const ImageQualityMetrics(
        blurScore: 0,
        glareRatio: 1,
        saturationStdDev: 0,
        contrastRatio: 0,
        overallScore: 0,
        issues: ['Empty image'],
      );
    }

    // RGBA pixel layout: [R, G, B, A, R, G, B, A, ...]
    // Each pixel is 4 bytes at offset (y * width + x) * 4.

    final saturationStdDev =
        _calcSaturationStdDevFromPixels(rgbaPixels, width, height);

    // Build grayscale luminance array for blur/glare/contrast
    final gray = Uint8List(totalPixels);
    for (int i = 0; i < totalPixels; i++) {
      final off = i * 4;
      final r = rgbaPixels.getUint8(off);
      final g = rgbaPixels.getUint8(off + 1);
      final b = rgbaPixels.getUint8(off + 2);
      // ITU-R BT.601 luminance
      gray[i] = ((r * 299 + g * 587 + b * 114) ~/ 1000);
    }

    final blurScore = _calcBlurScoreFromGray(gray, width, height);
    final glareRatio = _calcGlareRatioFromGray(gray);
    final contrastRatio = _calcContrastRatioFromGray(gray);

    return _buildMetrics(
      blurScore: blurScore,
      glareRatio: glareRatio,
      saturationStdDev: saturationStdDev,
      contrastRatio: contrastRatio,
    );
  }

  // ── Shared metrics builder ──

  ImageQualityMetrics _buildMetrics({
    required double blurScore,
    required double glareRatio,
    required double saturationStdDev,
    required double contrastRatio,
  }) {
    final issues = <String>[];
    if (blurScore < 50) issues.add('Image is blurry');
    if (glareRatio > 0.15) {
      issues.add('Severe glare detected (possible hologram)');
    }
    if (glareRatio > 0.05 && glareRatio <= 0.15) {
      issues.add('Moderate glare detected');
    }
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

  // ── image-package-based helpers (for analyze()) ──

  double _calculateBlurScore(img.Image grayscale) {
    final width = grayscale.width;
    final height = grayscale.height;

    if (width < 3 || height < 3) return 0;

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

  double _calculateGlareRatio(img.Image grayscale) {
    final totalPixels = grayscale.width * grayscale.height;
    if (totalPixels == 0) return 0;

    int overExposed = 0;
    for (final pixel in grayscale) {
      if (pixel.r > 240) overExposed++;
    }

    return overExposed / totalPixels;
  }

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

      final saturation = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
      saturations[idx++] = saturation;
    }

    return _stdDev(saturations, totalPixels);
  }

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

  // ── RGBA pixel-based helpers (for analyzeFromPixels()) ──

  double _calcBlurScoreFromGray(Uint8List gray, int width, int height) {
    if (width < 3 || height < 3) return 0;

    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final center = gray[y * width + x].toDouble();
        final top = gray[(y - 1) * width + x].toDouble();
        final bottom = gray[(y + 1) * width + x].toDouble();
        final left = gray[y * width + (x - 1)].toDouble();
        final right = gray[y * width + (x + 1)].toDouble();

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

  double _calcGlareRatioFromGray(Uint8List gray) {
    if (gray.isEmpty) return 0;

    int overExposed = 0;
    for (int i = 0; i < gray.length; i++) {
      if (gray[i] > 240) overExposed++;
    }

    return overExposed / gray.length;
  }

  double _calcSaturationStdDevFromPixels(
      ByteData rgba, int width, int height) {
    final totalPixels = width * height;
    if (totalPixels == 0) return 0;

    final saturations = Float64List(totalPixels);
    for (int i = 0; i < totalPixels; i++) {
      final off = i * 4;
      final r = rgba.getUint8(off) / 255.0;
      final g = rgba.getUint8(off + 1) / 255.0;
      final b = rgba.getUint8(off + 2) / 255.0;

      final maxC = max(r, max(g, b));
      final minC = min(r, min(g, b));

      saturations[i] = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
    }

    return _stdDev(saturations, totalPixels);
  }

  double _calcContrastRatioFromGray(Uint8List gray) {
    if (gray.isEmpty) return 0;

    int lMin = 255;
    int lMax = 0;

    for (int i = 0; i < gray.length; i++) {
      if (gray[i] < lMin) lMin = gray[i];
      if (gray[i] > lMax) lMax = gray[i];
    }

    final denominator = lMax + lMin;
    if (denominator == 0) return 0;

    return (lMax - lMin) / denominator;
  }

  // ── Shared helpers ──

  double _stdDev(Float64List values, int count) {
    double sum = 0;
    for (int i = 0; i < count; i++) {
      sum += values[i];
    }
    final mean = sum / count;

    double varianceSum = 0;
    for (int i = 0; i < count; i++) {
      final diff = values[i] - mean;
      varianceSum += diff * diff;
    }

    return sqrt(varianceSum / count);
  }

  double _calculateOverallScore({
    required double blurScore,
    required double glareRatio,
    required double saturationStdDev,
    required double contrastRatio,
  }) {
    final blurNorm = (blurScore / 200).clamp(0.0, 1.0);
    final glareNorm = (1.0 - (glareRatio / 0.3)).clamp(0.0, 1.0);
    final satNorm = (1.0 - (saturationStdDev / 0.5)).clamp(0.0, 1.0);
    final contrastNorm = (contrastRatio / 0.6).clamp(0.0, 1.0);

    return blurNorm * 0.35 +
        glareNorm * 0.30 +
        satNorm * 0.15 +
        contrastNorm * 0.20;
  }
}
