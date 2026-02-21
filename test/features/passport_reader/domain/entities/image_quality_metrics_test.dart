import 'package:eid_reader/features/passport_reader/domain/entities/image_quality_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageQualityMetrics', () {
    test('qualityLevel returns good for score >= 0.7', () {
      const metrics = ImageQualityMetrics(
        blurScore: 150,
        glareRatio: 0.02,
        saturationStdDev: 0.1,
        contrastRatio: 0.5,
        overallScore: 0.75,
      );
      expect(metrics.qualityLevel, ImageQualityLevel.good);
    });

    test('qualityLevel returns acceptable for score >= 0.5', () {
      const metrics = ImageQualityMetrics(
        blurScore: 80,
        glareRatio: 0.08,
        saturationStdDev: 0.2,
        contrastRatio: 0.3,
        overallScore: 0.55,
      );
      expect(metrics.qualityLevel, ImageQualityLevel.acceptable);
    });

    test('qualityLevel returns poor for score >= 0.3', () {
      const metrics = ImageQualityMetrics(
        blurScore: 30,
        glareRatio: 0.15,
        saturationStdDev: 0.3,
        contrastRatio: 0.15,
        overallScore: 0.35,
      );
      expect(metrics.qualityLevel, ImageQualityLevel.poor);
    });

    test('qualityLevel returns unusable for score < 0.3', () {
      const metrics = ImageQualityMetrics(
        blurScore: 10,
        glareRatio: 0.4,
        saturationStdDev: 0.4,
        contrastRatio: 0.05,
        overallScore: 0.15,
      );
      expect(metrics.qualityLevel, ImageQualityLevel.unusable);
    });

    test('boundary: score exactly 0.7 is good', () {
      const metrics = ImageQualityMetrics(
        blurScore: 100,
        glareRatio: 0.03,
        saturationStdDev: 0.1,
        contrastRatio: 0.4,
        overallScore: 0.7,
      );
      expect(metrics.qualityLevel, ImageQualityLevel.good);
    });

    test('boundary: score exactly 0.5 is acceptable', () {
      const metrics = ImageQualityMetrics(
        blurScore: 60,
        glareRatio: 0.1,
        saturationStdDev: 0.2,
        contrastRatio: 0.25,
        overallScore: 0.5,
      );
      expect(metrics.qualityLevel, ImageQualityLevel.acceptable);
    });

    test('boundary: score exactly 0.3 is poor', () {
      const metrics = ImageQualityMetrics(
        blurScore: 25,
        glareRatio: 0.2,
        saturationStdDev: 0.35,
        contrastRatio: 0.1,
        overallScore: 0.3,
      );
      expect(metrics.qualityLevel, ImageQualityLevel.poor);
    });

    test('issues list is empty by default', () {
      const metrics = ImageQualityMetrics(
        blurScore: 100,
        glareRatio: 0.01,
        saturationStdDev: 0.1,
        contrastRatio: 0.5,
        overallScore: 0.8,
      );
      expect(metrics.issues, isEmpty);
    });

    test('equatable compares by value', () {
      const m1 = ImageQualityMetrics(
        blurScore: 100,
        glareRatio: 0.05,
        saturationStdDev: 0.1,
        contrastRatio: 0.4,
        overallScore: 0.7,
        issues: ['test'],
      );
      const m2 = ImageQualityMetrics(
        blurScore: 100,
        glareRatio: 0.05,
        saturationStdDev: 0.1,
        contrastRatio: 0.4,
        overallScore: 0.7,
        issues: ['test'],
      );
      expect(m1, equals(m2));
    });
  });
}
