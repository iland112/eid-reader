import 'package:equatable/equatable.dart';

/// Confidence level for face comparison.
enum FaceComparisonConfidence {
  high,
  medium,
  low,
  unreliable,
}

/// Result of comparing a VIZ (camera) face with a chip (DG2) face.
class FaceComparisonResult extends Equatable {
  /// Cosine similarity score (0.0 - 1.0).
  final double similarityScore;

  /// Threshold used for match determination.
  final double threshold;

  const FaceComparisonResult({
    required this.similarityScore,
    required this.threshold,
  });

  /// Whether the faces match based on the threshold.
  bool get isMatch => similarityScore >= threshold;

  /// Confidence level based on similarity score.
  FaceComparisonConfidence get confidence {
    if (similarityScore >= 0.65) return FaceComparisonConfidence.high;
    if (similarityScore >= 0.50) return FaceComparisonConfidence.medium;
    if (similarityScore >= 0.35) return FaceComparisonConfidence.low;
    return FaceComparisonConfidence.unreliable;
  }

  @override
  List<Object?> get props => [similarityScore, threshold];
}
