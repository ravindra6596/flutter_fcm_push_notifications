import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('mr'));

class LocaleManager {
  static const key = 'selLangCode';

  /// Save selected language code
  static Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, locale.languageCode);
  }

  /// Load locale on startup
  static Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(key) ?? 'mr'; // default English
    appLocale.value = Locale(code);
  }
}
