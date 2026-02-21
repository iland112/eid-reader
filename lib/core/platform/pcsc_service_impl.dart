import 'package:dart_pcsc/dart_pcsc.dart';

import 'pcsc_service.dart';

/// PC/SC service implementation for Desktop (Windows/Linux).
class PcscServiceImpl implements PcscService {
  @override
  Future<PcscStatus> checkAvailability() async {
    final context = Context(Scope.user);
    try {
      await context.establish();
      final readers = await context.listReaders();
      return readers.isEmpty ? PcscStatus.noReaders : PcscStatus.available;
    } on Exception {
      return PcscStatus.notSupported;
    } finally {
      await context.release();
    }
  }

  @override
  Future<List<String>> listReaders() async {
    final context = Context(Scope.user);
    try {
      await context.establish();
      return await context.listReaders();
    } on Exception {
      return [];
    } finally {
      await context.release();
    }
  }
}
