import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/core/utils/country_code_utils.dart';

void main() {
  group('CountryCodeUtils.alpha3ToAlpha2', () {
    test('converts KOR to kr', () {
      expect(CountryCodeUtils.alpha3ToAlpha2('KOR'), 'kr');
    });

    test('converts USA to us', () {
      expect(CountryCodeUtils.alpha3ToAlpha2('USA'), 'us');
    });

    test('converts GBR to gb', () {
      expect(CountryCodeUtils.alpha3ToAlpha2('GBR'), 'gb');
    });

    test('converts DEU to de', () {
      expect(CountryCodeUtils.alpha3ToAlpha2('DEU'), 'de');
    });

    test('converts JPN to jp', () {
      expect(CountryCodeUtils.alpha3ToAlpha2('JPN'), 'jp');
    });

    test('is case-insensitive', () {
      expect(CountryCodeUtils.alpha3ToAlpha2('kor'), 'kr');
      expect(CountryCodeUtils.alpha3ToAlpha2('Kor'), 'kr');
    });

    test('returns null for unknown code', () {
      expect(CountryCodeUtils.alpha3ToAlpha2('ZZZ'), isNull);
    });

    test('returns null for empty string', () {
      expect(CountryCodeUtils.alpha3ToAlpha2(''), isNull);
    });

    test('handles ICAO-specific D<< code', () {
      expect(CountryCodeUtils.alpha3ToAlpha2('D<<'), 'de');
    });
  });

  group('CountryCodeUtils.flagAssetPath', () {
    test('returns correct path for KOR', () {
      expect(
        CountryCodeUtils.flagAssetPath('KOR'),
        'assets/svg/kr.svg',
      );
    });

    test('returns correct path for USA', () {
      expect(
        CountryCodeUtils.flagAssetPath('USA'),
        'assets/svg/us.svg',
      );
    });

    test('returns null for unknown code', () {
      expect(CountryCodeUtils.flagAssetPath('ZZZ'), isNull);
    });
  });
}
