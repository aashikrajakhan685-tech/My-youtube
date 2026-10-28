import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_item.dart';
import '../services/library_provider.dart';
import '../widgets/video_tile.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  Widget _list(List<VideoItem> items, String emptyText, IconData icon) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(emptyText, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (c, i) => VideoTile(video: items[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'clear') {
                  context.read<LibraryProvider>().clearHistory();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History saaf ho gayi')));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(value: 'clear', child: Text('History saaf karo')),
              ],
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'History'), Tab(text: 'Favorites')]),
        ),
        body: TabBarView(
          children: [
            _list(lib.history, 'Abhi koi history nahi', Icons.history),
            _list(lib.favorites, 'Abhi koi favorite nahi', Icons.favorite_border),
          ],
        ),
      ),
    );
  }
}
