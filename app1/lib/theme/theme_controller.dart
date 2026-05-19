import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  static const String _prefKey = 'app_theme_mode';

  /// Initialize theme from persistent storage. Call this before runApp.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefKey) ?? 'light';
      themeMode.value = stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      themeMode.value = ThemeMode.light;
    }
  }

  static Future<void> setLight() async {
    themeMode.value = ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, 'light');
  }

  static Future<void> setDark() async {
    themeMode.value = ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, 'dark');
  }

  static Future<void> toggle() async {
    if (themeMode.value == ThemeMode.dark) {
      await setLight();
    } else {
      await setDark();
    }
  }

  static bool get isDark => themeMode.value == ThemeMode.dark;
}

