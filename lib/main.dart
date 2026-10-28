import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'screens/root_screen.dart';
import 'services/library_provider.dart';
import 'services/playback_controller.dart';
import 'services/settings_provider.dart';
import 'services/theme_provider.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final playback = PlaybackController();
  unawaited(playback.initBackground()); // notification/background setup, app ko rokta nahi
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => LibraryProvider()),
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider<PlaybackController>.value(value: playback),
    ],
    child: const MyApp(),
  ));
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    return MaterialApp(title: 'My YouTube', debugShowCheckedModeBanner: false, theme: tp.currentTheme, home: const RootScreen());
  }
}
