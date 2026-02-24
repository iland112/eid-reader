import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../../../../core/services/face_embedding_service.dart';
import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../../mrz_input/domain/entities/viz_capture_result.dart';
import '../entities/face_comparison_result.dart';
import '../entities/image_quality_metrics.dart';
import '../entities/mrz_field_comparison.dart';
import '../entities/passport_data.dart';

final _log = Logger('VerifyViz');

/// Result of VIZ-chip cross-verification.
class VerifyVizResult {
  final FaceComparisonResult? faceComparison;
  final bool mrzFieldsMatch;
  final MrzFieldComparisonResult? fieldComparison;

  const VerifyVizResult({
    this.faceComparison,
    required this.mrzFieldsMatch,
    this.fieldComparison,
  });
}

/// Orchestrates VIZ-chip cross-verification:
/// 1. Compare VIZ face (camera) with chip DG2 face using embeddings
/// 2. Compare MRZ OCR fields with chip DG1 fields
class VerifyViz {
  final FaceEmbeddingService _embeddingService;

  /// Default match threshold.
  static const double defaultThreshold = 0.65;

  /// Threshold adjustment for poor quality images.
  static const double _poorQualityThresholdReduction = 0.15;

  VerifyViz({required FaceEmbeddingService embeddingService})
      : _embeddingService = embeddingService;

  /// Preloads the face embedding model so it's ready for comparison.
  /// Fire-and-forget — safe to call without awaiting.
  void preloadModel() {
    _embeddingService.preload().catchError((e) {
      _log.warning('Model preload failed: $e');
    });
  }

  /// Executes VIZ-chip verification.
  ///
  /// [vizCapture] - VIZ face image + quality metrics from camera.
  /// [chipData] - Passport data read from NFC chip (DG1/DG2).
  /// [ocrMrzData] - MRZ data from OCR scan.
  Future<VerifyVizResult> execute({
    required VizCaptureResult vizCapture,
    required PassportData chipData,
    required MrzData ocrMrzData,
  }) async {
    // 1. Compare MRZ OCR fields with chip DG1 fields
    final fieldComparison = _compareMrzFieldsDetailed(ocrMrzData, chipData);
    final mrzFieldsMatch = fieldComparison.allMatch;
    _log.fine(
        'MRZ fields: ${fieldComparison.matchCount}/${fieldComparison.totalFields} match');

    // 2. Compare faces if chip has face data
    FaceComparisonResult? faceComparison;
    if (chipData.faceImageBytes != null &&
        chipData.faceImageBytes!.isNotEmpty) {
      faceComparison = await _compareFaces(
        vizFaceBytes: vizCapture.vizFaceImageBytes,
        chipFaceBytes: chipData.faceImageBytes!,
        qualityMetrics: vizCapture.qualityMetrics,
      );
      _log.fine(
          'Face similarity: ${faceComparison.similarityScore.toStringAsFixed(3)}');
    } else {
      _log.fine('No chip face data available, skipping face comparison');
    }

    return VerifyVizResult(
      faceComparison: faceComparison,
      mrzFieldsMatch: mrzFieldsMatch,
      fieldComparison: fieldComparison,
    );
  }

  /// Compares VIZ camera face with chip DG2 face.
  Future<FaceComparisonResult> _compareFaces({
    required Uint8List vizFaceBytes,
    required Uint8List chipFaceBytes,
    required ImageQualityMetrics qualityMetrics,
  }) async {
    List<double>? vizEmbedding;
    List<double>? chipEmbedding;

    try {
      // Generate embeddings
      vizEmbedding = await _embeddingService.generateEmbedding(vizFaceBytes);
      chipEmbedding = await _embeddingService.generateEmbedding(chipFaceBytes);

      // Calculate similarity
      final similarity = cosineSimilarity(vizEmbedding, chipEmbedding);

      // Adjust threshold based on image quality
      var threshold = defaultThreshold;
      if (qualityMetrics.qualityLevel == ImageQualityLevel.poor ||
          qualityMetrics.qualityLevel == ImageQualityLevel.unusable) {
        threshold -= _poorQualityThresholdReduction;
        _log.fine(
            'Quality is ${qualityMetrics.qualityLevel.name}, threshold adjusted to $threshold');
      }

      return FaceComparisonResult(
        similarityScore: similarity.clamp(0.0, 1.0),
        threshold: threshold,
      );
    } finally {
      // Security: zero embedding vectors
      if (vizEmbedding != null) {
        for (int i = 0; i < vizEmbedding.length; i++) {
          vizEmbedding[i] = 0;
        }
      }
      if (chipEmbedding != null) {
        for (int i = 0; i < chipEmbedding.length; i++) {
          chipEmbedding[i] = 0;
        }
      }
    }
  }

  /// Compares MRZ OCR fields with chip DG1 fields, producing per-field results.
  MrzFieldComparisonResult _compareMrzFieldsDetailed(
    MrzData ocrData,
    PassportData chipData,
  ) {
    final matches = <MrzFieldMatch>[
      MrzFieldMatch(
        fieldName: 'Document Number',
        ocrValue: ocrData.documentNumber,
        chipValue: chipData.documentNumber,
        matches: ocrData.documentNumber == chipData.documentNumber,
      ),
      MrzFieldMatch(
        fieldName: 'Date of Birth',
        ocrValue: ocrData.dateOfBirth,
        chipValue: chipData.dateOfBirth,
        matches: _datesMatch(ocrData.dateOfBirth, chipData.dateOfBirth),
      ),
      MrzFieldMatch(
        fieldName: 'Date of Expiry',
        ocrValue: ocrData.dateOfExpiry,
        chipValue: chipData.dateOfExpiry,
        matches: _datesMatch(ocrData.dateOfExpiry, chipData.dateOfExpiry),
      ),
    ];

    // Add optional fields if OCR data has them
    if (ocrData.surname != null) {
      matches.add(MrzFieldMatch(
        fieldName: 'Surname',
        ocrValue: ocrData.surname,
        chipValue: chipData.surname,
        matches: _namesMatch(ocrData.surname, chipData.surname),
      ));
    }

    if (ocrData.givenNames != null) {
      matches.add(MrzFieldMatch(
        fieldName: 'Given Names',
        ocrValue: ocrData.givenNames,
        chipValue: chipData.givenNames,
        matches: _namesMatch(ocrData.givenNames, chipData.givenNames),
      ));
    }

    if (ocrData.nationality != null) {
      matches.add(MrzFieldMatch(
        fieldName: 'Nationality',
        ocrValue: ocrData.nationality,
        chipValue: chipData.nationality,
        matches: ocrData.nationality == chipData.nationality,
      ));
    }

    if (ocrData.sex != null && ocrData.sex!.isNotEmpty) {
      matches.add(MrzFieldMatch(
        fieldName: 'Sex',
        ocrValue: ocrData.sex,
        chipValue: chipData.sex,
        matches: ocrData.sex == chipData.sex,
      ));
    }

    return MrzFieldComparisonResult(fieldMatches: matches);
  }

  /// Compares names case-insensitively with whitespace normalization.
  bool _namesMatch(String? ocrName, String chipName) {
    if (ocrName == null) return false;
    final ocrNorm = ocrName.trim().toUpperCase();
    final chipNorm = chipName.trim().toUpperCase();
    if (ocrNorm == chipNorm) return true;

    // MRZ names are truncated to 39 chars; chip may have longer names
    if (chipNorm.length > 39 && ocrNorm == chipNorm.substring(0, 39).trim()) {
      return true;
    }
    return false;
  }

  /// Compares dates in YYMMDD and YYYYMMDD formats.
  bool _datesMatch(String ocrDate, String chipDate) {
    // Both in YYMMDD format
    if (ocrDate == chipDate) return true;

    // OCR is YYMMDD, chip might be YYYYMMDD
    if (chipDate.length == 8 && ocrDate.length == 6) {
      return chipDate.substring(2) == ocrDate;
    }

    return false;
  }
}
