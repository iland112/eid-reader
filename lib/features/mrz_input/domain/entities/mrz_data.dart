import 'package:equatable/equatable.dart';

/// MRZ data required for BAC/PACE authentication.
class MrzData extends Equatable {
  /// Passport document number (up to 9 characters).
  final String documentNumber;

  /// Date of birth in YYMMDD format.
  final String dateOfBirth;

  /// Date of expiry in YYMMDD format.
  final String dateOfExpiry;

  const MrzData({
    required this.documentNumber,
    required this.dateOfBirth,
    required this.dateOfExpiry,
  });

  @override
  List<Object?> get props => [documentNumber, dateOfBirth, dateOfExpiry];
}
