import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' show YoutubeExplode;
import '../services/library_provider.dart';

class SearchScreen extends StatefulWidget {
  final YoutubeExplode yt;
  const SearchScreen({super.key, required this.yt});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _c = TextEditingController();
  Timer? _debounce;
  List<String> _suggestions = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _submit(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    Navigator.pop(context, t);
  }

  void _onChanged(String text) {
    setState(() {});
    _debounce?.cancel();
    final t = text.trim();
    if (t.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final s = await widget.yt.search.getQuerySuggestions(t);
        if (mounted && _c.text.trim() == t) {
          setState(() => _suggestions = List<String>.from(s));
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final empty = _c.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _c,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _submit,
          onChanged: _onChanged,
          decoration: const InputDecoration(hintText: 'Search YouTube', border: InputBorder.none),
        ),
        actions: [
          if (!empty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _c.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: empty
          ? ListView(
              children: [
                if (lib.searches.isNotEmpty)
                  ListTile(
                    title: const Text('Recent searches', style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: TextButton(onPressed: () => lib.clearSearches(), child: const Text('Clear')),
                  ),
                ...lib.searches.map((q) => ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(q),
                      trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => lib.removeSearch(q)),
                      onTap: () => _submit(q),
                    )),
              ],
            )
          : ListView(
              children: _suggestions
                  .map((s) => ListTile(
                        leading: const Icon(Icons.search),
                        title: Text(s),
                        trailing: IconButton(
                          icon: const Icon(Icons.north_west, size: 18),
                          onPressed: () {
                            _c.text = s;
                            _c.selection = TextSelection.fromPosition(TextPosition(offset: s.length));
                            _onChanged(s);
                          },
                        ),
                        onTap: () => _submit(s),
                      ))
                  .toList(),
            ),
    );
  }
}
