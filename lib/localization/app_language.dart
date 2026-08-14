import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  az(code: 'az', label: 'Azərbaycan', flag: '🇦🇿'),
  ru(code: 'ru', label: 'Русский', flag: '🇷🇺');

  final String code;
  final String label;
  final String flag;

  const AppLanguage({
    required this.code,
    required this.label,
    required this.flag,
  });
}

class LanguageController extends ChangeNotifier {
  static const String _languageKey = 'app.language';

  final SharedPreferencesAsync _preferences;

  AppLanguage _language = AppLanguage.az;
  bool _hasSelectedLanguage = false;

  LanguageController({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  AppLanguage get language => _language;
  bool get hasSelectedLanguage => _hasSelectedLanguage;

  Future<void> load() async {
    final savedCode = await _preferences.getString(_languageKey);

    for (final language in AppLanguage.values) {
      if (language.code == savedCode) {
        _language = language;
        _hasSelectedLanguage = true;
        return;
      }
    }

    _language = AppLanguage.az;
    _hasSelectedLanguage = false;
  }

  Future<void> setLanguage(AppLanguage language) async {
    final changed = _language != language || !_hasSelectedLanguage;

    _language = language;
    _hasSelectedLanguage = true;

    if (changed) {
      notifyListeners();
    }

    await _preferences.setString(_languageKey, language.code);
  }
}

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static LanguageController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    assert(scope != null, 'LanguageScope is missing above this context.');
    return scope!.notifier!;
  }
}
