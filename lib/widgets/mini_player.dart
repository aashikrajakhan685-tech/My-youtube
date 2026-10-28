import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/player_screen.dart';
import '../services/playback_controller.dart';

/// Home/Library/Settings ke neeche dikhne wala chhota player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = context.watch<PlaybackController>();
    final v = pc.video;
    if (v == null) return const SizedBox.shrink();

    return Material(
      color: const Color(0xFF1E1E1E),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(video: v))),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              SizedBox(
                width: 100,
                height: 56,
                child: CachedNetworkImage(
                  imageUrl: v.thumb,
                  fit: BoxFit.cover,
                  errorWidget: (c, u, e) => Container(color: Colors.white10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(v.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              if (pc.loading)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                IconButton(
                  icon: Icon(pc.playing ? Icons.pause : Icons.play_arrow),
                  onPressed: () => pc.togglePlay(),
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => pc.stop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
