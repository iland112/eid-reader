/// ICAO 9303 state/organization codes for passport validation.
///
/// Used to validate and correct nationality and issuing state fields
/// extracted from MRZ OCR.
class IcaoCodes {
  IcaoCodes._();

  /// Common ICAO state codes (subset covering most passports).
  static const Set<String> validStateCodes = {
    // A
    'AFG', 'ALB', 'DZA', 'AND', 'AGO', 'ARG', 'ARM', 'AUS', 'AUT', 'AZE',
    // B
    'BHS', 'BHR', 'BGD', 'BRB', 'BLR', 'BEL', 'BLZ', 'BEN', 'BTN', 'BOL',
    'BIH', 'BWA', 'BRA', 'BRN', 'BGR', 'BFA', 'BDI',
    // C
    'KHM', 'CMR', 'CAN', 'CPV', 'CAF', 'TCD', 'CHL', 'CHN', 'COL', 'COM',
    'COG', 'COD', 'CRI', 'CIV', 'HRV', 'CUB', 'CYP', 'CZE',
    // D
    'DNK', 'DJI', 'DMA', 'DOM', 'D', 'DEU',
    // E
    'ECU', 'EGY', 'SLV', 'GNQ', 'ERI', 'EST', 'ETH',
    // F
    'FJI', 'FIN', 'FRA',
    // G
    'GAB', 'GMB', 'GEO', 'GHA', 'GRC', 'GRD', 'GTM', 'GIN', 'GNB', 'GUY',
    'GBR',
    // H
    'HTI', 'HND', 'HKG', 'HUN',
    // I
    'ISL', 'IND', 'IDN', 'IRN', 'IRQ', 'IRL', 'ISR', 'ITA',
    // J
    'JAM', 'JPN', 'JOR',
    // K
    'KAZ', 'KEN', 'KIR', 'PRK', 'KOR', 'KWT', 'KGZ',
    // L
    'LAO', 'LVA', 'LBN', 'LSO', 'LBR', 'LBY', 'LIE', 'LTU', 'LUX',
    // M
    'MAC', 'MKD', 'MDG', 'MWI', 'MYS', 'MDV', 'MLI', 'MLT', 'MHL', 'MRT',
    'MUS', 'MEX', 'FSM', 'MDA', 'MCO', 'MNG', 'MNE', 'MAR', 'MOZ', 'MMR',
    // N
    'NAM', 'NRU', 'NPL', 'NLD', 'NZL', 'NIC', 'NER', 'NGA', 'NOR',
    // O
    'OMN',
    // P
    'PAK', 'PLW', 'PAN', 'PNG', 'PRY', 'PER', 'PHL', 'POL', 'PRT',
    // Q
    'QAT',
    // R
    'ROU', 'RUS', 'RWA',
    // S
    'KNA', 'LCA', 'VCT', 'WSM', 'SMR', 'STP', 'SAU', 'SEN', 'SRB', 'SYC',
    'SLE', 'SGP', 'SVK', 'SVN', 'SLB', 'SOM', 'ZAF', 'ESP', 'LKA', 'SDN',
    'SUR', 'SWZ', 'SWE', 'CHE', 'SYR',
    // T
    'TWN', 'TJK', 'TZA', 'THA', 'TLS', 'TGO', 'TON', 'TTO', 'TUN', 'TUR',
    'TKM', 'TUV',
    // U
    'UGA', 'UKR', 'ARE', 'USA', 'URY', 'UZB', 'UTO',
    // V
    'VUT', 'VEN', 'VNM',
    // Y
    'YEM',
    // Z
    'ZMB', 'ZWE',
    // Special/organization codes
    'UNO', 'UNA', 'UNK', 'XOM', 'XXA', 'XXB', 'XXC',
    'EUE',
  };

  /// Returns true if the code is a valid ICAO state code.
  static bool isValidStateCode(String code) {
    return validStateCodes.contains(code.toUpperCase());
  }

  /// Attempts to correct a possibly mis-OCR'd state code by trying
  /// single-character substitutions from the confusion matrix.
  /// Returns the corrected code if exactly one valid alternative is found,
  /// otherwise returns null.
  static String? correctStateCode(String code) {
    if (code.length != 3) return null;
    if (isValidStateCode(code)) return code;

    final upper = code.toUpperCase();
    final candidates = <String>{};

    for (int i = 0; i < 3; i++) {
      final alternatives = _confusionAlternatives(upper[i]);
      for (final alt in alternatives) {
        final corrected =
            upper.substring(0, i) + alt + upper.substring(i + 1);
        if (validStateCodes.contains(corrected)) {
          candidates.add(corrected);
        }
      }
    }

    // Only return if exactly one valid correction found (unambiguous)
    if (candidates.length == 1) return candidates.first;
    return null;
  }

  /// Returns visually similar alternatives for a character.
  static List<String> _confusionAlternatives(String c) {
    return switch (c) {
      'O' => ['0', 'Q', 'D'],
      '0' => ['O', 'Q', 'D'],
      'I' => ['1', 'L'],
      '1' => ['I', 'L'],
      'L' => ['I', '1'],
      'S' => ['5'],
      '5' => ['S'],
      'Z' => ['2'],
      '2' => ['Z'],
      'B' => ['8'],
      '8' => ['B'],
      'G' => ['6'],
      '6' => ['G'],
      'T' => ['7'],
      '7' => ['T'],
      _ => [],
    };
  }
}
