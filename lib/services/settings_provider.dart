import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool sponsorBlock = true;

  /// 0 = Auto (sabse achhi quality jisme awaaz saath aati hai), warna max height jaise 360/720/1080
  int defaultQuality = 0;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    sponsorBlock = p.getBool('sponsorBlock') ?? true;
    defaultQuality = p.getInt('defaultQuality') ?? 0;
    notifyListeners();
  }

  Future<void> setSponsorBlock(bool v) async {
    sponsorBlock = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('sponsorBlock', v);
  }

  Future<void> setDefaultQuality(int q) async {
    defaultQuality = q;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('defaultQuality', q);
  }
}
