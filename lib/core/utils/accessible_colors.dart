import 'package:flutter/material.dart';

/// WCAG AA accessible color constants.
///
/// Each pair provides a foreground color that achieves at least
/// 4.5:1 contrast ratio against the typical background for both
/// light mode (white/near-white surface) and dark mode (dark surface).
class AccessibleColors {
  AccessibleColors._();

  // ── Success (green) ──

  /// Light mode: dark green on white → contrast ~10:1.
  static const successLight = Color(0xFF1B5E20);

  /// Dark mode: light green on dark surface → contrast ~7:1.
  static const successDark = Color(0xFF81C784);

  // ── Warning (orange) ──

  /// Light mode: dark orange on white → contrast ~5.4:1.
  static const warningLight = Color(0xFFBF360C);

  /// Dark mode: light orange on dark surface → contrast ~7.3:1.
  static const warningDark = Color(0xFFFFB74D);

  // ── Info (blue) ──

  /// Light mode: dark blue on white → contrast ~7.5:1.
  static const infoLight = Color(0xFF0D47A1);

  /// Dark mode: light blue on dark surface → contrast ~6.5:1.
  static const infoDark = Color(0xFF90CAF9);

  // ── Error (red) ──

  /// Light mode: dark red on white → contrast ~7.8:1.
  static const errorLight = Color(0xFFB71C1C);

  /// Dark mode: light red on dark surface → contrast ~5.5:1.
  static const errorDark = Color(0xFFEF9A9A);

  /// Returns the appropriate success color for the current brightness.
  static Color success(Brightness brightness) =>
      brightness == Brightness.dark ? successDark : successLight;

  /// Returns the appropriate warning color for the current brightness.
  static Color warning(Brightness brightness) =>
      brightness == Brightness.dark ? warningDark : warningLight;

  /// Returns the appropriate error color for the current brightness.
  static Color error(Brightness brightness) =>
      brightness == Brightness.dark ? errorDark : errorLight;

  /// Returns the appropriate info color for the current brightness.
  static Color info(Brightness brightness) =>
      brightness == Brightness.dark ? infoDark : infoLight;
}
