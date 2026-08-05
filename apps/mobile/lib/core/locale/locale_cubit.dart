// Locale Cubit — VSP Mobile App
//
// Owns the app's display language. The choice is persisted so it survives
// restarts, and `null` means "follow the device language" (the default).
//
// Supported: English (en) and Vietnamese (vi).

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locales the app ships translations for.
const List<Locale> kSupportedLocales = [Locale('en'), Locale('vi')];

/// Holds the selected [Locale], or `null` to follow the device setting.
class LocaleCubit extends Cubit<Locale?> {
  static const String _prefsKey = 'app_locale';

  LocaleCubit() : super(null);

  /// Loads the saved preference. Safe to call before the first frame; a
  /// missing or unreadable preference just leaves the device language in use.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null && kSupportedLocales.any((l) => l.languageCode == code)) {
        emit(Locale(code));
      }
    } catch (_) {
      // Preferences unavailable — stay on the device language.
    }
  }

  /// Switches the app language. Pass `null` to follow the device language.
  Future<void> setLocale(Locale? locale) async {
    emit(locale);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, locale.languageCode);
      }
    } catch (_) {
      // Persisting failed — the in-memory choice still applies this session.
    }
  }
}
