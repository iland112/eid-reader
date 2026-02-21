import 'dart:typed_data';

import '../../domain/entities/pa_verification_result.dart';

/// Abstract interface for Passive Authentication verification service.
abstract class PaService {
  Future<PaVerificationResult> verify({
    required Uint8List sodBytes,
    required Uint8List dg1Bytes,
    required Uint8List dg2Bytes,
    String? issuingCountry,
    String? documentNumber,
  });
}
