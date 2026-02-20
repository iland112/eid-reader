import '../../../mrz_input/domain/entities/mrz_data.dart';
import '../../domain/entities/passport_data.dart';

/// Abstract interface for passport reading datasources.
///
/// Implementations:
/// - [NfcPassportDatasource]: Reads via NFC using dmrtd library.
abstract class PassportDatasource {
  Future<PassportData> readPassport(MrzData mrzData);
}
