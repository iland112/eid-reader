import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/app/device_capability_provider.dart';

void main() {
  group('ChipReaderCapability', () {
    test('hasChipReader returns true for nfcEnabled', () {
      expect(hasChipReader(ChipReaderCapability.nfcEnabled), isTrue);
    });

    test('hasChipReader returns true for pcscAvailable', () {
      expect(hasChipReader(ChipReaderCapability.pcscAvailable), isTrue);
    });

    test('hasChipReader returns false for nfcDisabled', () {
      expect(hasChipReader(ChipReaderCapability.nfcDisabled), isFalse);
    });

    test('hasChipReader returns false for none', () {
      expect(hasChipReader(ChipReaderCapability.none), isFalse);
    });
  });

  group('ChipReaderCapability enum', () {
    test('has 4 values', () {
      expect(ChipReaderCapability.values.length, 4);
    });

    test('contains expected values', () {
      expect(ChipReaderCapability.values, contains(ChipReaderCapability.nfcEnabled));
      expect(ChipReaderCapability.values, contains(ChipReaderCapability.nfcDisabled));
      expect(ChipReaderCapability.values, contains(ChipReaderCapability.pcscAvailable));
      expect(ChipReaderCapability.values, contains(ChipReaderCapability.none));
    });
  });
}
