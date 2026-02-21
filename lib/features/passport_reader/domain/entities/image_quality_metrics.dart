import 'package:equatable/equatable.dart';

/// Quality level classification for VIZ face images.
enum ImageQualityLevel {
  good,
  acceptable,
  poor,
  unusable,
}

/// Image quality metrics for hologram/glare detection on VIZ face photos.
///
/// Uses purely computational metrics (no ML model) to assess whether
/// hologram interference, blur, or glare is degrading the captured face image.
class ImageQualityMetrics extends Equatable {
  /// Laplacian variance: higher = sharper image.
  /// > 100: good, 50-100: acceptable, < 50: poor.
  final double blurScore;

  /// Ratio of over-exposed pixels (luminance > 240) in the face region.
  /// < 0.05: good, 0.05-0.15: moderate glare, > 0.15: severe glare.
  final double glareRatio;

  /// Standard deviation of saturation in HSV color space.
  /// > 0.25 suggests hologram rainbow pattern interference.
  final double saturationStdDev;

  /// Michelson contrast: (Lmax - Lmin) / (Lmax + Lmin).
  /// > 0.3: good, < 0.15: washed out.
  final double contrastRatio;

  /// Weighted overall score (0.0 - 1.0).
  final double overallScore;

  /// Detected quality issues.
  final List<String> issues;

  const ImageQualityMetrics({
    required this.blurScore,
    required this.glareRatio,
    required this.saturationStdDev,
    required this.contrastRatio,
    required this.overallScore,
    this.issues = const [],
  });

  /// Classification based on overall score.
  ImageQualityLevel get qualityLevel {
    if (overallScore >= 0.7) return ImageQualityLevel.good;
    if (overallScore >= 0.5) return ImageQualityLevel.acceptable;
    if (overallScore >= 0.3) return ImageQualityLevel.poor;
    return ImageQualityLevel.unusable;
  }

  @override
  List<Object?> get props => [
        blurScore,
        glareRatio,
        saturationStdDev,
        contrastRatio,
        overallScore,
        issues,
      ];
}
