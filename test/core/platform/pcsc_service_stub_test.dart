import 'package:eid_reader/core/platform/pcsc_service.dart';
import 'package:eid_reader/core/platform/pcsc_service_stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PcscServiceStub', () {
    late PcscServiceStub service;

    setUp(() {
      service = PcscServiceStub();
    });

    test('checkAvailability returns notSupported', () async {
      final status = await service.checkAvailability();
      expect(status, PcscStatus.notSupported);
    });

    test('listReaders returns empty list', () async {
      final readers = await service.listReaders();
      expect(readers, isEmpty);
    });

    test('implements PcscService', () {
      expect(service, isA<PcscService>());
    });
  });
}
