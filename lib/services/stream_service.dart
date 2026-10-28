import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Ek quality option. audioUrl null hai to stream me awaaz already hai (muxed).
/// audioUrl null nahi hai to HD video-only stream hai aur awaaz alag se judti hai
/// (player dono ko ek saath chalata hai, bilkul YouTube ki tarah).
class QualityOption {
  final String label;
  final int height;
  final String url;
  final String? audioUrl;
  const QualityOption({required this.label, required this.height, required this.url, this.audioUrl});

  bool get isMuxed => audioUrl == null;
}

class _Cand {
  final int h;
  final String url;
  final int score;
  _Cand(this.h, this.url, this.score);
}

class StreamService {
  // Library ke versions me field ke naam alag ho sakte hain, isliye yeh sab
  // dynamic tareeke se padhe jaate hain: koi naam na mile to app crash nahi hoti.

  static int _heightOf(dynamic s) {
    final readers = <String Function()>[
      () => s.qualityLabel as String,
      () => s.videoQualityLabel as String,
    ];
    for (final read in readers) {
      try {
        final m = RegExp(r'(\d{3,4})p').firstMatch(read());
        if (m != null) return int.parse(m.group(1)!);
      } catch (_) {}
    }
    try {
      return (s.videoResolution.height as num).toInt();
    } catch (_) {}
    return 0;
  }

  static int _bps(dynamic s) {
    try {
      return (s.bitrate.bitsPerSecond as num).toInt();
    } catch (_) {}
    try {
      return (s.size.totalBytes as num).toInt();
    } catch (_) {}
    return 0;
  }

  static String _codec(dynamic s) {
    try {
      return (s.videoCodec as String).toLowerCase();
    } catch (_) {
      return '';
    }
  }

  static String _mime(String url) {
    try {
      return (Uri.parse(url).queryParameters['mime'] ?? '').toLowerCase();
    } catch (_) {
      return '';
    }
  }

  static String _label(int h) {
    if (h >= 2160) return '${h}p • 4K';
    if (h >= 1440) return '${h}p • 2K';
    return '${h}p';
  }

  /// Zyada score = behtar. 1080p tak: H.264 > VP9 > AV1 (phone me hardware decode hota hai).
  /// 1080p se upar (2K/4K): VP9 > AV1.
  static int _videoScore(dynamic s, String url, int h) {
    final codec = _codec(s);
    final mime = _mime(url);
    final isAvc = codec.startsWith('avc') || (codec.isEmpty && mime.contains('mp4'));
    final isVp9 = codec.startsWith('vp09') || codec.startsWith('vp9') || (codec.isEmpty && mime.contains('webm'));
    final isAv1 = codec.startsWith('av01');
    int rank;
    if (h <= 1080) {
      rank = isAvc ? 3 : (isVp9 ? 2 : (isAv1 ? 1 : 2));
    } else {
      rank = isVp9 ? 3 : (isAv1 ? 2 : 1);
    }
    return rank * (1 << 40) + _bps(s);
  }

  static Map<int, _Cand> _bestPerHeight(List<_Cand> list) {
    final out = <int, _Cand>{};
    for (final c in list) {
      final cur = out[c.h];
      if (cur == null || c.score > cur.score) out[c.h] = c;
    }
    return out;
  }

  /// Sabse achhi audio. Auto-dubbed (doosri bhasha wali) tracks ko chhodta hai,
  /// taaki video ki asli awaaz aaye.
  static String? _bestAudioUrl(Iterable<dynamic> audios) {
    String? best;
    String? bestAny;
    var bestBps = -1;
    var bestAnyBps = -1;
    for (final a in audios) {
      final url = a.url.toString();
      final bps = _bps(a);
      if (bps > bestAnyBps) {
        bestAnyBps = bps;
        bestAny = url;
      }
      if (!url.contains('dubbed') && bps > bestBps) {
        bestBps = bps;
        best = url;
      }
    }
    return best ?? bestAny;
  }

  /// Pehle library ke default clients, phir androidVr, phir safari. Jo pehle chale wahi.
  static Future<StreamManifest> _manifest(YoutubeExplode yt, String id) async {
    Object? lastError;
    final attempts = <List<YoutubeApiClient>?>[
      null,
      [YoutubeApiClient.androidVr],
      [YoutubeApiClient.safari],
    ];
    for (final clients in attempts) {
      try {
        final m = clients == null
            ? await yt.videos.streams.getManifest(id)
            : await yt.videos.streams.getManifest(id, ytClients: clients);
        if (m.muxed.isNotEmpty || m.videoOnly.isNotEmpty) return m;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Is video ki koi playable stream nahi mili.');
  }

  static Future<List<QualityOption>> load(YoutubeExplode yt, String videoId) async {
    final manifest = await _manifest(yt, videoId);

    final muxed = <_Cand>[];
    for (final s in manifest.muxed) {
      final h = _heightOf(s);
      final url = s.url.toString();
      if (h > 0) muxed.add(_Cand(h, url, _videoScore(s, url, h)));
    }

    final vOnly = <_Cand>[];
    for (final s in manifest.videoOnly) {
      final h = _heightOf(s);
      final url = s.url.toString();
      if (h > 0) vOnly.add(_Cand(h, url, _videoScore(s, url, h)));
    }

    final audioUrl = _bestAudioUrl(manifest.audioOnly);

    final bestMuxed = _bestPerHeight(muxed);
    final bestVideoOnly = _bestPerHeight(vOnly);
    final heights = <int>{...bestMuxed.keys, ...bestVideoOnly.keys}.toList()..sort((a, b) => b.compareTo(a));

    final options = <QualityOption>[];
    for (final h in heights) {
      final m = bestMuxed[h];
      if (m != null) {
        options.add(QualityOption(label: _label(h), height: h, url: m.url));
      } else if (audioUrl != null) {
        final v = bestVideoOnly[h]!;
        options.add(QualityOption(label: _label(h), height: h, url: v.url, audioUrl: audioUrl));
      }
    }

    if (options.isEmpty) {
      throw Exception('Is video ki koi playable stream nahi mili.');
    }
    return options;
  }

  /// pref = 0 -> Auto: 1080p tak ki sabse achhi quality (HD, video + awaaz alag judkar).
  /// pref > 0 -> us height ya usse neeche ki sabse achhi quality (2K/4K bhi chun sakte ho).
  static QualityOption pick(List<QualityOption> opts, int pref) {
    final limit = pref == 0 ? 1080 : pref;
    for (final o in opts) {
      if (o.height <= limit) return o;
    }
    return opts.last;
  }

  /// HD na chale to bharose wali (awaaz ke saath wali) stream.
  static QualityOption? bestMuxed(List<QualityOption> opts) {
    for (final o in opts) {
      if (o.isMuxed) return o;
    }
    return null;
  }
}
