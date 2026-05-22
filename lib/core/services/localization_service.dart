import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

class LocalizationService extends GetxService {
  static const String _langKey = 'selectedLanguage';
  final _sharedPrefs = Get.find<SharedPreferences>();
  final Rx<Locale> _locale;

  LocalizationService() : _locale = Rx<Locale>(const Locale('en', 'US'));

  static const locales = [
    Locale('en', 'US'),
    Locale('fr', 'FR'),
    Locale('ar', 'MA'),
  ];

  static final fallbackLocale = Locale('en', 'US');

  Locale get currentLocale => _locale.value;
  Rx<Locale> get currentLocaleObs => _locale;

  @override
  void onInit() {
    super.onInit();
    _locale.value = _loadSavedLocale();
  }

  Locale _loadSavedLocale() {
    final langCode = _sharedPrefs.getString(_langKey);
    if (langCode != null) {
      return Locale(langCode);
    }

    final systemLocale = ui.window.locale;
    if (locales.any((l) => l.languageCode == systemLocale.languageCode)) {
      return Locale(systemLocale.languageCode);
    }

    return fallbackLocale;
  }

  void updateLocale(String langCode) {
    final locale = Locale(langCode);
    _locale.value = locale;
    Get.updateLocale(locale);
    _sharedPrefs.setString(_langKey, langCode);
  }
}
