import 'pcsc_service.dart';

/// Stub PC/SC service for platforms without PC/SC support (Android).
class PcscServiceStub implements PcscService {
  @override
  Future<PcscStatus> checkAvailability() async {
    return PcscStatus.notSupported;
  }

  @override
  Future<List<String>> listReaders() async {
    return [];
  }
}
