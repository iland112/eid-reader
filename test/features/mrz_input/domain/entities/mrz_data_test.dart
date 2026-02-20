import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/features/mrz_input/domain/entities/mrz_data.dart';

void main() {
  group('MrzData', () {
    test('two instances with same values are equal', () {
      const a = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
      );
      const b = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two instances with different values are not equal', () {
      const a = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
      );
      const b = MrzData(
        documentNumber: 'X123456',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
      );
      expect(a, isNot(equals(b)));
    });

    test('props contains all three fields', () {
      const data = MrzData(
        documentNumber: 'L898902C',
        dateOfBirth: '690806',
        dateOfExpiry: '940623',
      );
      expect(data.props, ['L898902C', '690806', '940623']);
    });
  });
}
