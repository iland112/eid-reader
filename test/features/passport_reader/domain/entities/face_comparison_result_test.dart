import 'package:eid_reader/features/passport_reader/domain/entities/face_comparison_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaceComparisonResult', () {
    test('isMatch returns true when score >= threshold', () {
      const result = FaceComparisonResult(
        similarityScore: 0.70,
        threshold: 0.65,
      );
      expect(result.isMatch, isTrue);
    });

    test('isMatch returns true when score equals threshold', () {
      const result = FaceComparisonResult(
        similarityScore: 0.65,
        threshold: 0.65,
      );
      expect(result.isMatch, isTrue);
    });

    test('isMatch returns false when score < threshold', () {
      const result = FaceComparisonResult(
        similarityScore: 0.60,
        threshold: 0.65,
      );
      expect(result.isMatch, isFalse);
    });

    test('confidence is high for score >= 0.65', () {
      const result = FaceComparisonResult(
        similarityScore: 0.75,
        threshold: 0.65,
      );
      expect(result.confidence, FaceComparisonConfidence.high);
    });

    test('confidence is medium for score 0.50-0.65', () {
      const result = FaceComparisonResult(
        similarityScore: 0.55,
        threshold: 0.50,
      );
      expect(result.confidence, FaceComparisonConfidence.medium);
    });

    test('confidence is low for score 0.35-0.50', () {
      const result = FaceComparisonResult(
        similarityScore: 0.40,
        threshold: 0.35,
      );
      expect(result.confidence, FaceComparisonConfidence.low);
    });

    test('confidence is unreliable for score < 0.35', () {
      const result = FaceComparisonResult(
        similarityScore: 0.20,
        threshold: 0.35,
      );
      expect(result.confidence, FaceComparisonConfidence.unreliable);
    });

    test('equatable compares by value', () {
      const r1 = FaceComparisonResult(
        similarityScore: 0.75,
        threshold: 0.65,
      );
      const r2 = FaceComparisonResult(
        similarityScore: 0.75,
        threshold: 0.65,
      );
      expect(r1, equals(r2));
    });
  });
}
