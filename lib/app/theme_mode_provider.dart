import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  void toggle() {
    switch (state) {
      case ThemeMode.system:
      case ThemeMode.light:
        state = ThemeMode.dark;
      case ThemeMode.dark:
        state = ThemeMode.light;
    }
  }
}
