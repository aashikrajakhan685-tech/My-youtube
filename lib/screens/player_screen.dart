import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../models/video_item.dart';
import '../services/library_provider.dart';
import '../services/playback_controller.dart';
import '../services/settings_provider.dart';
import '../utils.dart';

/// Player ka sirf "dikhne wala" hissa. Asli player PlaybackController me hai,
/// isliye is screen se back karne par bhi gana chalta rehta hai.
class PlayerScreen extends StatefulWidget {
  final VideoItem video;
  const PlayerScreen({super.key, required this.video});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlaybackController _pc;
  late final VoidCallback _skipHandler;

  @override
  void initState() {
    super.initState();
    _pc = context.read<PlaybackController>();
    _skipHandler = () {
      if (!mounted) return;
      final m = ScaffoldMessenger.of(context);
      m.hideCurrentSnackBar();
      m.showSnackBar(const SnackBar(content: Text('Sponsor wala hissa skip ho gaya'), duration: Duration(milliseconds: 1500)));
    };
    _pc.onSkip = _skipHandler;
    _pc.setScreenVisible(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pc.open(widget.video, context.read<SettingsProvider>(), context.read<LibraryProvider>());
    });
  }

  @override
  void dispose() {
    if (_pc.onSkip == _skipHandler) _pc.onSkip = null;
    _pc.setScreenVisible(false);
    super.dispose();
  }

  void _retry() {
    _pc.open(widget.video, context.read<SettingsProvider>(), context.read<LibraryProvider>());
  }

  void _pickQuality() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: _pc.options
              .map((o) => ListTile(
                    title: Text(o.label),
                    subtitle: Text(o.isMuxed
                        ? 'Awaaz ke saath (reliable)'
                        : (o.height > 1080 ? 'Bahut heavy: sirf strong phone par smooth' : 'HD (video + awaaz alag judti hai)')),
                    trailing: _pc.current?.url == o.url ? const Icon(Icons.check) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pc.switchQuality(o);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _pickSpeed() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: speeds
              .map((s) => ListTile(
                    title: Text(s == 1.0 ? 'Normal' : '${s}x'),
                    trailing: _pc.speed == s ? const Icon(Icons.check) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pc.setSpeed(s);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
            const SizedBox(height: 8),
            Text(msg, textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pc = context.watch<PlaybackController>();
    final fav = context.watch<LibraryProvider>().isFav(widget.video.id);
    final same = pc.video?.id == widget.video.id;
    final loading = !same || pc.loading;
    final error = same ? pc.error : null;
    final playerError = same ? pc.playerError : null;
    final views = (same && pc.views > 0) ? pc.views : widget.video.views;
    final meta = [widget.video.author, fmtViews(views)].where((e) => e.isNotEmpty).join(' • ');

    return Scaffold(
      appBar: AppBar(title: Text(widget.video.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Positioned.fill(child: Video(controller: pc.controller)),
                if (loading) const Positioned.fill(child: Center(child: CircularProgressIndicator())),
                if (!loading && error != null) Positioned.fill(child: _errorBox(error)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (playerError != null && error == null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Expanded(child: Text('Player error: $playerError', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12))),
                        TextButton(onPressed: pc.options.isEmpty ? _retry : _pickQuality, child: Text(pc.options.isEmpty ? 'Retry' : 'Quality badlo')),
                      ],
                    ),
                  ),
                if (same && pc.notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(pc.notice!, style: const TextStyle(color: Colors.amber, fontSize: 12)),
                  ),
                Text(widget.video.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(meta, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Favorite',
                      icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? Colors.redAccent : null),
                      onPressed: () => context.read<LibraryProvider>().toggleFav(widget.video),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.hd_outlined, size: 18),
                      label: Text((same ? pc.current?.label : null) ?? 'Quality'),
                      onPressed: (same && pc.options.isNotEmpty) ? _pickQuality : null,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.speed, size: 18),
                      label: Text(pc.speed == 1.0 ? 'Speed' : '${pc.speed}x'),
                      onPressed: _pickSpeed,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.link, size: 18),
                      label: const Text('Link'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.video.link));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copy ho gaya')));
                      },
                    ),
                    FilterChip(
                      label: Text('SponsorBlock${(same && pc.skipped > 0) ? ' (${pc.skipped})' : ''}'),
                      selected: pc.sbEnabled,
                      onSelected: (v) => pc.toggleSponsor(v),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Back dabane, app minimize ya screen lock karne par bhi gana chalta rahega. Notification ya neeche mini player se control karo.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (same && pc.description.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Description'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(pc.description, style: const TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
