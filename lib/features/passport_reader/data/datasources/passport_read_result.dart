import 'dart:typed_data';

import '../../domain/entities/passport_data.dart';

/// Result of reading a passport, including raw bytes for PA verification.
class PassportReadResult {
  final PassportData passportData;
  final Uint8List sodBytes;
  final Uint8List dg1Bytes;
  final Uint8List dg2Bytes;

  const PassportReadResult({
    required this.passportData,
    required this.sodBytes,
    required this.dg1Bytes,
    required this.dg2Bytes,
  });
}
