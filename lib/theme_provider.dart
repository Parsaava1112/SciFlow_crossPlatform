import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { defaultTheme, nature, ocean, golden }

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  AppTheme _appTheme = AppTheme.defaultTheme;

  static const String _themeModeKey = 'theme_mode';
  static const String _appThemeKey = 'app_theme';

  ThemeMode get themeMode => _themeMode;
  AppTheme get appTheme => _appTheme;

  ThemeProvider() {
    _loadTheme();
  }

  // ---------- تم‌های روشن ----------
  ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return ThemeData.light().copyWith(
      colorScheme: colorScheme,
      fontFamily: 'Vazirmatn', // ← اگه فونت رو اضافه کردی؛ در غیر اینصورت خط رو حذف کن
    );
  }

  // ---------- تم‌های تاریک ----------
  ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    return ThemeData.dark().copyWith(
      colorScheme: colorScheme,
      fontFamily: 'Vazirmatn',
    );
  }

  // ---------- رنگ پایه بر اساس تم انتخاب‌شده ----------
  Color get _seedColor {
    switch (_appTheme) {
      case AppTheme.nature:
        return Colors.green;
      case AppTheme.ocean:
        return Colors.blue;
      case AppTheme.golden:
        return Colors.amber;
      case AppTheme.defaultTheme:
      default:
        return Colors.indigo;
    }
  }

  // ---------- تغییر حالت روشن/تاریک ----------
  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final value = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await prefs.setString(_themeModeKey, value);
  }

  // ---------- تغییر تم رنگی ----------
  Future<void> setAppTheme(AppTheme theme) async {
    _appTheme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appThemeKey, theme.name);
  }

  // ---------- بارگذاری تنظیمات ذخیره‌شده ----------
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    // بارگذاری حالت روشن/تاریک
    final modeString = prefs.getString(_themeModeKey) ?? 'light';
    switch (modeString) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'system':
        _themeMode = ThemeMode.system;
        break;
      default:
        _themeMode = ThemeMode.light;
    }

    // بارگذاری تم رنگی
    final appThemeString = prefs.getString(_appThemeKey) ?? AppTheme.defaultTheme.name;
    _appTheme = AppTheme.values.firstWhere(
      (e) => e.name == appThemeString,
      orElse: () => AppTheme.defaultTheme,
    );

    notifyListeners();
  }
}