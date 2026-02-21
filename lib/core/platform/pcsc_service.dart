/// PC/SC smart card reader availability status.
enum PcscStatus {
  /// PC/SC service is available with readers connected.
  available,

  /// PC/SC service is running but no readers connected.
  noReaders,

  /// PC/SC service is not available on this platform.
  notSupported,
}

/// Abstract interface for checking PC/SC smart card reader availability.
///
/// On Desktop (Windows/Linux): implemented via dart_pcsc.
/// On Android: stub that returns [PcscStatus.notSupported].
abstract class PcscService {
  /// Check PC/SC reader availability.
  Future<PcscStatus> checkAvailability();

  /// List connected reader names.
  Future<List<String>> listReaders();
}
