import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' show YoutubeExplode;
import '../models/video_item.dart';
import '../services/library_provider.dart';
import '../utils.dart';
import '../widgets/video_tile.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final YoutubeExplode _yt = YoutubeExplode();
  final ScrollController _scroll = ScrollController();

  static const Map<String, String> _chips = {
    'Trending': 'trending videos today',
    'Music': 'new music videos',
    'Gaming': 'gaming',
    'News': 'latest news',
    'Live': 'live now',
    'Movies': 'movie trailers',
    'Sports': 'sports highlights',
    'Tech': 'tech reviews',
    'Comedy': 'comedy',
  };

  String _chip = 'Trending';
  String _query = 'trending videos today';
  List<VideoItem> _items = [];
  dynamic _page; // search ka current page (nextPage() ke liye)
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        _loadMore();
      }
    });
    _search(_query);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _yt.close();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final id = ++_reqId;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _hasMore = true;
      _error = null;
      _query = q;
    });
    try {
      final page = await _yt.search.search(q);
      if (!mounted || id != _reqId) return;
      setState(() {
        _page = page;
        _items = page.map<VideoItem>((v) => VideoItem.fromVideo(v)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore || _page == null) return;
    final id = _reqId;
    setState(() => _loadingMore = true);
    try {
      final next = await _page.nextPage();
      if (!mounted || id != _reqId) return;
      if (next == null || next.isEmpty) {
        setState(() {
          _hasMore = false;
          _loadingMore = false;
        });
        return;
      }
      final seen = _items.map((e) => e.id).toSet();
      final more = <VideoItem>[];
      for (final v in next) {
        final it = VideoItem.fromVideo(v);
        if (seen.add(it.id)) more.add(it);
      }
      setState(() {
        _page = next;
        _items = [..._items, ...more];
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && id == _reqId) {
        setState(() {
          _loadingMore = false;
          _hasMore = false;
        });
      }
    }
  }

  Future<void> _openSearch() async {
    final q = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => SearchScreen(yt: _yt)));
    if (!mounted || q == null || q.trim().isEmpty) return;
    context.read<LibraryProvider>().addSearch(q.trim());
    setState(() => _chip = '');
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _search(q.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _openSearch,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(24)),
            child: const Row(
              children: [
                Icon(Icons.search, size: 20),
                SizedBox(width: 8),
                Text('Search YouTube', style: TextStyle(fontSize: 15, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: _chips.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(e.key),
                          selected: _chip == e.key,
                          onSelected: (_) {
                            setState(() => _chip = e.key);
                            if (_scroll.hasClients) _scroll.jumpTo(0);
                            _search(e.value);
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null && _items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _search(_query),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            Center(
              child: FilledButton.icon(
                onPressed: () => _search(_query),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _search(_query),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (c, i) {
          if (i >= _items.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }
          return VideoTile(video: _items[i]);
        },
      ),
    );
  }
}
