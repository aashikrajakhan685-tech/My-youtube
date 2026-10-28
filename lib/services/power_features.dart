import 'dart:convert';
import 'package:http/http.dart' as http;

class PowerFeatures {
  static const categories = ['sponsor', 'selfpromo', 'interaction'];

  static Future<List<SponsorSegment>> getSponsorSegments(String videoId) async {
    try {
      final url = Uri.https('sponsor.ajay.app', '/api/skipSegments', {
        'videoID': videoId,
        'categories': jsonEncode(categories),
      });
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final out = <SponsorSegment>[];
        for (final e in data) {
          final seg = e['segment'] as List;
          out.add(SponsorSegment(
            start: (seg[0] as num).toDouble(),
            end: (seg[1] as num).toDouble(),
            category: (e['category'] ?? 'sponsor') as String,
          ));
        }
        return out;
      }
    } catch (_) {}
    return [];
  }
}

class SponsorSegment {
  final double start;
  final double end;
  final String category;
  SponsorSegment({required this.start, required this.end, this.category = 'sponsor'});
}
