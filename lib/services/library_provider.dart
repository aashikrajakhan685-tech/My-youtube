import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_item.dart';

class LibraryProvider extends ChangeNotifier {
  List<VideoItem> history = [];
  List<VideoItem> favorites = [];
  List<String> searches = [];

  LibraryProvider() {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    history = _readItems(p.getString('history'));
    favorites = _readItems(p.getString('favorites'));
    searches = p.getStringList('searches') ?? [];
    notifyListeners();
  }

  List<VideoItem> _readItems(String? raw) {
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveItems(String key, List<VideoItem> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  bool isFav(String id) => favorites.any((v) => v.id == id);

  Future<void> addHistory(VideoItem v) async {
    history.removeWhere((e) => e.id == v.id);
    history.insert(0, v);
    if (history.length > 100) history = history.sublist(0, 100);
    notifyListeners();
    await _saveItems('history', history);
  }

  Future<void> clearHistory() async {
    history = [];
    notifyListeners();
    await _saveItems('history', history);
  }

  Future<void> toggleFav(VideoItem v) async {
    if (isFav(v.id)) {
      favorites.removeWhere((e) => e.id == v.id);
    } else {
      favorites.insert(0, v);
    }
    notifyListeners();
    await _saveItems('favorites', favorites);
  }

  Future<void> addSearch(String q) async {
    searches.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    searches.insert(0, q);
    if (searches.length > 15) searches = searches.sublist(0, 15);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('searches', searches);
  }

  Future<void> removeSearch(String q) async {
    searches.remove(q);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('searches', searches);
  }

  Future<void> clearSearches() async {
    searches = [];
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('searches', searches);
  }
}
