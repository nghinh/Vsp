// Which palette the app draws in, and who decides.
//
// The app was hard-wired to dark: `themeMode: ThemeMode.dark`, no setting, no
// way out. That was right while dark was the only palette the widgets could
// actually render — several hundred of them named the dark tokens directly, so
// a light theme would have gone light behind text that stayed dark-mode pale.
//
// That is no longer true. Every widget reads its colours from the theme, and
// the light palette has been measured against WCAG on the surfaces it is drawn
// on. So the choice can go to the golfer, where it belongs.
//
// The default stays dark rather than following the device. Not because dark is
// better, but because it is what every golfer using this app has today, and a
// silent flip on update — turning a screen somebody has learned to read at a
// glance into a different screen without asking — is a worse first impression
// than an option they have not found yet. Following the device is one tap
// away in Settings, and it is the first option listed.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the chosen [ThemeMode] and remembers it across restarts.
class ThemeModeCubit extends Cubit<ThemeMode> {
  static const String _prefsKey = 'app_theme_mode';

  /// Where a golfer who has never opened Settings starts. See the note above.
  static const ThemeMode defaultMode = ThemeMode.dark;

  ThemeModeCubit() : super(defaultMode);

  /// Loads the saved preference. Safe to call before the first frame; an
  /// unreadable preference simply leaves the default in place.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      final mode = _decode(saved);
      if (mode != null) emit(mode);
    } catch (_) {
      // Preferences unavailable — stay on the default.
    }
  }

  /// Switches the palette and remembers the choice.
  Future<void> setMode(ThemeMode mode) async {
    emit(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // Persisting failed — the choice still applies for this session.
    }
  }

  /// Stored by name rather than by index: an index is a promise about the
  /// order of an enum somebody else maintains, and reordering it would
  /// silently change what every golfer's phone is set to.
  static ThemeMode? _decode(String? saved) {
    for (final mode in ThemeMode.values) {
      if (mode.name == saved) return mode;
    }
    return null;
  }
}
