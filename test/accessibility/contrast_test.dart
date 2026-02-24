import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eid_reader/core/utils/accessible_colors.dart';

/// Calculates WCAG 2.1 relative luminance from a [Color].
///
/// See: https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
double _relativeLuminance(Color color) {
  double linearize(double channel) {
    return channel <= 0.04045
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = linearize(color.r);
  final g = linearize(color.g);
  final b = linearize(color.b);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Calculates WCAG contrast ratio between two colors.
///
/// See: https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio
double _contrastRatio(Color foreground, Color background) {
  final lumFg = _relativeLuminance(foreground);
  final lumBg = _relativeLuminance(background);
  final lighter = math.max(lumFg, lumBg);
  final darker = math.min(lumFg, lumBg);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // Typical Material 3 surface colors
  const lightBackground = Color(0xFFFFFFFF); // White
  const darkBackground = Color(0xFF1C1B1F); // Material 3 dark surface

  group('AccessibleColors WCAG AA contrast (4.5:1 minimum)', () {
    test('successLight on white background meets 4.5:1', () {
      final ratio =
          _contrastRatio(AccessibleColors.successLight, lightBackground);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason:
              'successLight contrast ratio is $ratio, must be >= 4.5:1');
    });

    test('successDark on dark background meets 4.5:1', () {
      final ratio =
          _contrastRatio(AccessibleColors.successDark, darkBackground);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason:
              'successDark contrast ratio is $ratio, must be >= 4.5:1');
    });

    test('warningLight on white background meets 4.5:1', () {
      final ratio =
          _contrastRatio(AccessibleColors.warningLight, lightBackground);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason:
              'warningLight contrast ratio is $ratio, must be >= 4.5:1');
    });

    test('warningDark on dark background meets 4.5:1', () {
      final ratio =
          _contrastRatio(AccessibleColors.warningDark, darkBackground);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason:
              'warningDark contrast ratio is $ratio, must be >= 4.5:1');
    });

    test('errorLight on white background meets 4.5:1', () {
      final ratio =
          _contrastRatio(AccessibleColors.errorLight, lightBackground);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason:
              'errorLight contrast ratio is $ratio, must be >= 4.5:1');
    });

    test('errorDark on dark background meets 4.5:1', () {
      final ratio =
          _contrastRatio(AccessibleColors.errorDark, darkBackground);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'errorDark contrast ratio is $ratio, must be >= 4.5:1');
    });
  });

  group('AccessibleColors brightness-based selection', () {
    test('success() returns successLight for Brightness.light', () {
      expect(
        AccessibleColors.success(Brightness.light),
        AccessibleColors.successLight,
      );
    });

    test('success() returns successDark for Brightness.dark', () {
      expect(
        AccessibleColors.success(Brightness.dark),
        AccessibleColors.successDark,
      );
    });

    test('warning() returns warningLight for Brightness.light', () {
      expect(
        AccessibleColors.warning(Brightness.light),
        AccessibleColors.warningLight,
      );
    });

    test('warning() returns warningDark for Brightness.dark', () {
      expect(
        AccessibleColors.warning(Brightness.dark),
        AccessibleColors.warningDark,
      );
    });

    test('error() returns errorLight for Brightness.light', () {
      expect(
        AccessibleColors.error(Brightness.light),
        AccessibleColors.errorLight,
      );
    });

    test('error() returns errorDark for Brightness.dark', () {
      expect(
        AccessibleColors.error(Brightness.dark),
        AccessibleColors.errorDark,
      );
    });
  });

  group('AccessibleColors color values are distinct', () {
    test('success colors differ between light and dark', () {
      expect(
          AccessibleColors.successLight, isNot(AccessibleColors.successDark));
    });

    test('warning colors differ between light and dark', () {
      expect(
          AccessibleColors.warningLight, isNot(AccessibleColors.warningDark));
    });

    test('error colors differ between light and dark', () {
      expect(AccessibleColors.errorLight, isNot(AccessibleColors.errorDark));
    });

    test('all light colors are distinct from each other', () {
      expect(
          AccessibleColors.successLight, isNot(AccessibleColors.warningLight));
      expect(
          AccessibleColors.successLight, isNot(AccessibleColors.errorLight));
      expect(
          AccessibleColors.warningLight, isNot(AccessibleColors.errorLight));
    });

    test('all dark colors are distinct from each other', () {
      expect(
          AccessibleColors.successDark, isNot(AccessibleColors.warningDark));
      expect(
          AccessibleColors.successDark, isNot(AccessibleColors.errorDark));
      expect(
          AccessibleColors.warningDark, isNot(AccessibleColors.errorDark));
    });
  });
}
