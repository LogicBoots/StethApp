import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider {
  static const String _languageKey = 'selected_language';

  final ValueNotifier<Locale> _currentLocale = ValueNotifier<Locale>(
    const Locale('en', ''),
  );

  ValueNotifier<Locale> get currentLocale => _currentLocale;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey) ?? 'en';
      _currentLocale.value = Locale(languageCode, '');
    } catch (e) {
      // Default to English if there's an error
      _currentLocale.value = const Locale('en', '');
    }
  }

  Future<void> setLanguage(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      _currentLocale.value = Locale(languageCode, '');
    } catch (e) {
      // Handle error silently, keep current language
      print('Error saving language preference: $e');
    }
  }

  String get currentLanguageCode => _currentLocale.value.languageCode;

  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'hi': 'हिन्दी',
  };

  String getLanguageName(String code) {
    return supportedLanguages[code] ?? 'English';
  }
}
