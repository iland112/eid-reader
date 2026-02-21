import 'package:equatable/equatable.dart';

/// Result of comparing a single MRZ field between OCR and chip data.
class MrzFieldMatch extends Equatable {
  final String fieldName;
  final String? ocrValue;
  final String chipValue;
  final bool matches;

  const MrzFieldMatch({
    required this.fieldName,
    required this.ocrValue,
    required this.chipValue,
    required this.matches,
  });

  @override
  List<Object?> get props => [fieldName, ocrValue, chipValue, matches];
}

/// Aggregate result of comparing all MRZ fields.
class MrzFieldComparisonResult extends Equatable {
  final List<MrzFieldMatch> fieldMatches;

  const MrzFieldComparisonResult({required this.fieldMatches});

  bool get allMatch => fieldMatches.every((f) => f.matches);
  int get matchCount => fieldMatches.where((f) => f.matches).length;
  int get totalFields => fieldMatches.length;

  @override
  List<Object?> get props => [fieldMatches];
}
