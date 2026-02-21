import 'dart:typed_data';
import 'dart:ui';

import 'package:eid_reader/core/services/face_embedding_service.dart';
import 'package:eid_reader/features/mrz_input/domain/entities/mrz_data.dart';
import 'package:eid_reader/features/mrz_input/domain/entities/viz_capture_result.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/face_comparison_result.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/image_quality_metrics.dart';
import 'package:eid_reader/features/passport_reader/domain/entities/passport_data.dart';
import 'package:eid_reader/features/passport_reader/domain/usecases/verify_viz.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock embedding service that returns predetermined embeddings.
class MockFaceEmbeddingService implements FaceEmbeddingService {
  List<double> vizEmbedding = List.filled(192, 0.5);
  List<double> chipEmbedding = List.filled(192, 0.5);
  int callCount = 0;

  @override
  Future<List<double>> generateEmbedding(Uint8List faceImageBytes) async {
    callCount++;
    // First call is VIZ, second is chip
    if (callCount % 2 == 1) return List.from(vizEmbedding);
    return List.from(chipEmbedding);
  }

  @override
  void close() {}
}

VizCaptureResult _createVizCapture({
  ImageQualityLevel qualityLevel = ImageQualityLevel.good,
}) {
  final overallScore = switch (qualityLevel) {
    ImageQualityLevel.good => 0.8,
    ImageQualityLevel.acceptable => 0.6,
    ImageQualityLevel.poor => 0.35,
    ImageQualityLevel.unusable => 0.1,
  };
  return VizCaptureResult(
    vizFaceImageBytes: Uint8List.fromList([1, 2, 3]),
    faceBoundingBox: const Rect.fromLTWH(50, 60, 80, 100),
    qualityMetrics: ImageQualityMetrics(
      blurScore: 100,
      glareRatio: 0.02,
      saturationStdDev: 0.1,
      contrastRatio: 0.5,
      overallScore: overallScore,
    ),
  );
}

final _defaultFace = Uint8List.fromList([4, 5, 6]);

PassportData _createChipData({
  String documentNumber = 'AB1234567',
  String dateOfBirth = '900115',
  String dateOfExpiry = '301215',
  Uint8List? faceImageBytes,
  bool hasFace = true,
}) {
  return PassportData(
    surname: 'DOE',
    givenNames: 'JOHN',
    documentNumber: documentNumber,
    nationality: 'USA',
    dateOfBirth: dateOfBirth,
    sex: 'M',
    dateOfExpiry: dateOfExpiry,
    issuingState: 'USA',
    documentType: 'P',
    faceImageBytes: hasFace ? (faceImageBytes ?? _defaultFace) : null,
  );
}

MrzData _createMrzData({
  String documentNumber = 'AB1234567',
  String dateOfBirth = '900115',
  String dateOfExpiry = '301215',
}) {
  return MrzData(
    documentNumber: documentNumber,
    dateOfBirth: dateOfBirth,
    dateOfExpiry: dateOfExpiry,
  );
}

void main() {
  late MockFaceEmbeddingService mockEmbedding;
  late VerifyViz verifyViz;

  setUp(() {
    mockEmbedding = MockFaceEmbeddingService();
    verifyViz = VerifyViz(embeddingService: mockEmbedding);
  });

  group('VerifyViz', () {
    test('matching MRZ fields returns mrzFieldsMatch true', () async {
      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(),
        ocrMrzData: _createMrzData(),
      );

      expect(result.mrzFieldsMatch, isTrue);
    });

    test('mismatching document number returns mrzFieldsMatch false', () async {
      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(documentNumber: 'XY9876543'),
        ocrMrzData: _createMrzData(),
      );

      expect(result.mrzFieldsMatch, isFalse);
    });

    test('mismatching date of birth returns mrzFieldsMatch false', () async {
      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(dateOfBirth: '950220'),
        ocrMrzData: _createMrzData(),
      );

      expect(result.mrzFieldsMatch, isFalse);
    });

    test('YYYYMMDD chip date matches YYMMDD OCR date', () async {
      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(dateOfBirth: '19900115'),
        ocrMrzData: _createMrzData(dateOfBirth: '900115'),
      );

      expect(result.mrzFieldsMatch, isTrue);
    });

    test('identical embeddings produce high similarity', () async {
      // Both return same embedding → cosine similarity ≈ 1.0
      mockEmbedding.vizEmbedding = List.filled(192, 0.5);
      mockEmbedding.chipEmbedding = List.filled(192, 0.5);

      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(),
        ocrMrzData: _createMrzData(),
      );

      expect(result.faceComparison, isNotNull);
      expect(result.faceComparison!.similarityScore, closeTo(1.0, 0.01));
      expect(result.faceComparison!.isMatch, isTrue);
      expect(result.faceComparison!.confidence, FaceComparisonConfidence.high);
    });

    test('different embeddings produce low similarity', () async {
      mockEmbedding.vizEmbedding = List.generate(192, (i) => i.toDouble());
      mockEmbedding.chipEmbedding =
          List.generate(192, (i) => (191 - i).toDouble());

      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(),
        ocrMrzData: _createMrzData(),
      );

      expect(result.faceComparison, isNotNull);
      expect(result.faceComparison!.similarityScore, lessThan(0.65));
    });

    test('poor quality reduces threshold', () async {
      mockEmbedding.vizEmbedding = List.filled(192, 0.5);
      mockEmbedding.chipEmbedding = List.filled(192, 0.5);

      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(qualityLevel: ImageQualityLevel.poor),
        chipData: _createChipData(),
        ocrMrzData: _createMrzData(),
      );

      expect(result.faceComparison, isNotNull);
      expect(result.faceComparison!.threshold,
          VerifyViz.defaultThreshold - 0.15);
    });

    test('no chip face skips face comparison', () async {
      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(faceImageBytes: Uint8List(0)),
        ocrMrzData: _createMrzData(),
      );

      expect(result.faceComparison, isNull);
      expect(result.mrzFieldsMatch, isTrue);
    });

    test('null chip face skips face comparison', () async {
      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(hasFace: false),
        ocrMrzData: _createMrzData(),
      );

      expect(result.faceComparison, isNull);
    });

    test('embedding service called twice for face comparison', () async {
      await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(),
        ocrMrzData: _createMrzData(),
      );

      expect(mockEmbedding.callCount, 2);
    });

    test('returns field comparison with core fields', () async {
      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(),
        ocrMrzData: _createMrzData(),
      );

      expect(result.fieldComparison, isNotNull);
      // 3 core fields: doc number, DOB, DOE
      expect(result.fieldComparison!.totalFields, 3);
      expect(result.fieldComparison!.allMatch, isTrue);
    });

    test('field comparison includes optional fields from OCR', () async {
      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(),
        ocrMrzData: const MrzData(
          documentNumber: 'AB1234567',
          dateOfBirth: '900115',
          dateOfExpiry: '301215',
          surname: 'DOE',
          givenNames: 'JOHN',
          nationality: 'USA',
          sex: 'M',
        ),
      );

      expect(result.fieldComparison, isNotNull);
      // 3 core + surname, givenNames, nationality, sex = 7
      expect(result.fieldComparison!.totalFields, 7);
      expect(result.fieldComparison!.allMatch, isTrue);
    });

    test('field comparison shows mismatching surname', () async {
      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(),
        ocrMrzData: const MrzData(
          documentNumber: 'AB1234567',
          dateOfBirth: '900115',
          dateOfExpiry: '301215',
          surname: 'SMITH',
        ),
      );

      expect(result.fieldComparison, isNotNull);
      final surnameMatch = result.fieldComparison!.fieldMatches
          .firstWhere((f) => f.fieldName == 'Surname');
      expect(surnameMatch.matches, isFalse);
      expect(surnameMatch.ocrValue, 'SMITH');
      expect(surnameMatch.chipValue, 'DOE');
    });

    test('name comparison is case-insensitive', () async {
      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(),
        ocrMrzData: const MrzData(
          documentNumber: 'AB1234567',
          dateOfBirth: '900115',
          dateOfExpiry: '301215',
          surname: 'doe',
          givenNames: 'john',
        ),
      );

      expect(result.fieldComparison, isNotNull);
      final surnameMatch = result.fieldComparison!.fieldMatches
          .firstWhere((f) => f.fieldName == 'Surname');
      expect(surnameMatch.matches, isTrue);
    });

    test('mrzFieldsMatch reflects allMatch from fieldComparison', () async {
      final result = await verifyViz.execute(
        vizCapture: _createVizCapture(),
        chipData: _createChipData(documentNumber: 'XY9876543'),
        ocrMrzData: const MrzData(
          documentNumber: 'AB1234567',
          dateOfBirth: '900115',
          dateOfExpiry: '301215',
          surname: 'DOE',
        ),
      );

      expect(result.mrzFieldsMatch, isFalse);
      expect(result.fieldComparison!.allMatch, isFalse);
    });
  });
}
