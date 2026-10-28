import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
class ThemeProvider extends ChangeNotifier {
  String _themeName = 'Dark';
  String get themeName => _themeName;
  ThemeData get currentTheme => AppThemes.themes[_themeName] ?? AppThemes.themes['Dark']!;
  ThemeProvider() { _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeName = prefs.getString('theme') ?? 'Dark';
    notifyListeners();
  }
  Future<void> setTheme(String name) async {
    _themeName = name; notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', name);
  }
}
