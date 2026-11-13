import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages app theme mode (Light, Dark, System).
/// Defaults to [ThemeMode.light] for CareFlow's clinical light-first identity.
class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'careflow_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themePrefKey);
      if (savedMode != null) {
        switch (savedMode) {
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'system':
            _themeMode = ThemeMode.system;
            break;
          case 'light':
          default:
            _themeMode = ThemeMode.light;
            break;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ThemeProvider: failed to load preference: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String modeStr;
      switch (mode) {
        case ThemeMode.dark:
          modeStr = 'dark';
          break;
        case ThemeMode.system:
          modeStr = 'system';
          break;
        case ThemeMode.light:
          modeStr = 'light';
          break;
      }
      await prefs.setString(_themePrefKey, modeStr);
    } catch (e) {
      debugPrint('ThemeProvider: failed to save preference: $e');
    }
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}
