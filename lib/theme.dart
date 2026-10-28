import 'package:flutter/material.dart';
class AppThemes {
  static final Map<String, ThemeData> themes = {
    'Dark': ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: const Color(0xFF0F0F0F), colorScheme: const ColorScheme.dark(primary: Colors.redAccent)),
    'AMOLED': ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: Colors.black, colorScheme: const ColorScheme.dark(primary: Colors.redAccent)),
    'Ocean': ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: const Color(0xFF0D1B2A), colorScheme: const ColorScheme.dark(primary: Colors.cyan)),
  };
}
