import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/core/platform/secure_screen_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureScreenServiceImpl', () {
    late SecureScreenServiceImpl service;
    final List<MethodCall> log = [];

    setUp(() {
      service = SecureScreenServiceImpl();
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.smartcoreinc.eid_reader/secure_screen'),
        (MethodCall methodCall) async {
          log.add(methodCall);
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.smartcoreinc.eid_reader/secure_screen'),
        null,
      );
    });

    test('enableSecureMode calls correct method', () async {
      await service.enableSecureMode();
      expect(log, hasLength(1));
      expect(log.first.method, 'enableSecureMode');
    });

    test('disableSecureMode calls correct method', () async {
      await service.disableSecureMode();
      expect(log, hasLength(1));
      expect(log.first.method, 'disableSecureMode');
    });

    test('methods can be called sequentially', () async {
      await service.enableSecureMode();
      await service.disableSecureMode();
      expect(log, hasLength(2));
      expect(log[0].method, 'enableSecureMode');
      expect(log[1].method, 'disableSecureMode');
    });
  });
}
