import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  static const String _themeKey = 'isDarkMode';
  final _sharedPrefs = Get.find<SharedPreferences>();
  
  final _isDarkMode = false.obs;
  bool get isDarkMode => _isDarkMode.value;

  ThemeMode get themeMode {
    final storedValue = _sharedPrefs.getBool(_themeKey);
    if (storedValue == null) return ThemeMode.system;
    return storedValue ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  void onInit() {
    super.onInit();
    _loadTheme();
  }

  void _loadTheme() {
    final storedValue = _sharedPrefs.getBool(_themeKey);
    if (storedValue != null) {
      _isDarkMode.value = storedValue;
    } else {
      // If no preference, use system setting
      _isDarkMode.value = Get.isPlatformDarkMode;
    }
  }

  void toggleTheme() {
    _isDarkMode.value = !_isDarkMode.value;
    Get.changeThemeMode(_isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
    _sharedPrefs.setBool(_themeKey, _isDarkMode.value);
  }

  void setThemeMode(ThemeMode mode) {
    Get.changeThemeMode(mode);
    if (mode == ThemeMode.system) {
      _sharedPrefs.remove(_themeKey);
      _isDarkMode.value = Get.isPlatformDarkMode;
    } else {
      final isDark = mode == ThemeMode.dark;
      _isDarkMode.value = isDark;
      _sharedPrefs.setBool(_themeKey, isDark);
    }
  }
}
