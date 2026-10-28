import 'package:youtube_explode_dart/youtube_explode_dart.dart' show Video;

class VideoItem {
  final String id;
  final String title;
  final String author;
  final int durationSec;
  final int views;
  final bool isLive;

  const VideoItem({
    required this.id,
    required this.title,
    required this.author,
    this.durationSec = 0,
    this.views = 0,
    this.isLive = false,
  });

  String get thumb => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
  String get link => 'https://youtu.be/$id';

  factory VideoItem.fromVideo(Video v) => VideoItem(
        id: v.id.value,
        title: v.title,
        author: v.author,
        durationSec: v.duration?.inSeconds ?? 0,
        views: v.engagement.viewCount,
        isLive: v.isLive,
      );

  factory VideoItem.fromJson(Map<String, dynamic> j) => VideoItem(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        author: (j['author'] ?? '') as String,
        durationSec: (j['d'] ?? 0) as int,
        views: (j['v'] ?? 0) as int,
        isLive: (j['l'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'd': durationSec,
        'v': views,
        'l': isLive,
      };
}
