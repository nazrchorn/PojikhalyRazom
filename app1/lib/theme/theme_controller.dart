import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static void setLight() => themeMode.value = ThemeMode.light;
  static void setDark() => themeMode.value = ThemeMode.dark;

  static bool get isDark => themeMode.value == ThemeMode.dark;
}

