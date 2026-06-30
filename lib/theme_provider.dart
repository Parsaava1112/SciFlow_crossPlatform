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
    final base = ThemeData.light();
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return _applyFont(
      base.copyWith(colorScheme: colorScheme),
    );
  }

  // ---------- تم‌های تاریک ----------
  ThemeData get darkTheme {
    final base = ThemeData.dark();
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    return _applyFont(
      base.copyWith(colorScheme: colorScheme),
    );
  }

  // ---------- اعمال فونت (در صورت وجود) ----------
  ThemeData _applyFont(ThemeData theme) {
    // اگر فونت وزیرمتن را اضافه کرده‌ای، کامنت‌ها را بردار
    // return theme.copyWith(
    //   textTheme: theme.textTheme.apply(fontFamily: 'Vazirmatn'),
    //   primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Vazirmatn'),
    // );
    return theme; // بدون فونت
  }

  // ---------- رنگ پایه ----------
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

    final appThemeString = prefs.getString(_appThemeKey) ?? AppTheme.defaultTheme.name;
    _appTheme = AppTheme.values.firstWhere(
      (e) => e.name == appThemeString,
      orElse: () => AppTheme.defaultTheme,
    );

    notifyListeners();
  }
}