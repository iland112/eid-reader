import '../../../mrz_input/domain/entities/mrz_data.dart';
import 'passport_read_result.dart';

/// Abstract interface for passport reading datasources.
///
/// Implementations:
/// - [NfcPassportDatasource]: Reads via NFC using dmrtd library.
abstract class PassportDatasource {
  Future<PassportReadResult> readPassport(MrzData mrzData);
}
