import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/video_item.dart';
import '../screens/player_screen.dart';
import '../services/library_provider.dart';
import '../utils.dart';

class VideoTile extends StatelessWidget {
  final VideoItem video;
  const VideoTile({super.key, required this.video});

  Widget _badge(String text, Color color) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final fav = lib.isFav(video.id);
    final meta = [video.author, fmtViews(video.views)].where((e) => e.isNotEmpty).join(' • ');

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(video: video))),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: video.thumb,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (c, u) => Container(color: Colors.white10),
                    errorWidget: (c, u, e) => Container(color: Colors.white10, child: const Icon(Icons.broken_image_outlined)),
                  ),
                ),
                if (video.isLive)
                  _badge('LIVE', Colors.red)
                else if (video.durationSec > 0)
                  _badge(fmtDuration(video.durationSec), Colors.black87),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) {
                      if (v == 'fav') {
                        context.read<LibraryProvider>().toggleFav(video);
                      } else if (v == 'link') {
                        Clipboard.setData(ClipboardData(text: video.link));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copy ho gaya')));
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(value: 'fav', child: Text(fav ? 'Favorites se hatao' : 'Favorites me jodo')),
                      const PopupMenuItem<String>(value: 'link', child: Text('Link copy karo')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
