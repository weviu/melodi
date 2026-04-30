import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// A single YouTube search result.
class YtSearchResult {
  final String id;
  final String title;
  final String channel;
  final String duration; // e.g. "3:45"
  final String thumbnailUrl;

  const YtSearchResult({
    required this.id,
    required this.title,
    required this.channel,
    required this.duration,
    required this.thumbnailUrl,
  });
}

class YtDlpService {
  static const _defaultUrl = 'https://aprhunter.route07.com/melodi';
  static const _defaultKey =
      '3c1d1c53ad09c3eedc145218f7b0cb5aebac41350ea956c734a9d43bad650920';

  static const prefUrlKey = 'server_url';
  static const prefKeyKey = 'server_key';

  Future<({String url, String key})> _config() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      url: prefs.getString(prefUrlKey) ?? _defaultUrl,
      key: prefs.getString(prefKeyKey) ?? _defaultKey,
    );
  }

  /// Search YouTube and return up to [maxResults] results.
  Future<List<YtSearchResult>> search(String query,
      {int maxResults = 20}) async {
    final cfg = await _config();
    final uri = Uri.parse('${cfg.url}/search')
        .replace(queryParameters: {'q': query, 'limit': '$maxResults'});

    final response = await http
        .get(uri, headers: {'x-api-key': cfg.key})
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Search failed (${response.statusCode}): ${response.body}');
    }

    final list =
        (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    return list
        .map((e) => YtSearchResult(
              id: e['id'] as String? ?? '',
              title: e['title'] as String? ?? 'Unknown',
              channel: e['channel'] as String? ?? '',
              duration: e['duration'] as String? ?? '0:00',
              thumbnailUrl: e['thumbnailUrl'] as String? ?? '',
            ))
        .toList();
  }

  /// Download [videoId] as MP3 into [outputDir].
  /// Also saves thumbnail as a .jpg sidecar if [thumbnailUrl] is provided.
  /// Calls [onProgress] with values 0.0–1.0.
  /// Returns the path to the downloaded MP3.
  Future<String> downloadMp3(
    String videoId,
    String outputDir, {
    String thumbnailUrl = '',
    void Function(double progress)? onProgress,
  }) async {
    final cfg = await _config();
    final uri = Uri.parse('${cfg.url}/download');

    final request = http.Request('POST', uri)
      ..headers['x-api-key'] = cfg.key
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'url': 'https://www.youtube.com/watch?v=$videoId'});

    final client = http.Client();
    try {
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 60));

      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        throw Exception('Download failed (${streamed.statusCode}): $body');
      }

      // Server sends X-Filename (URL-encoded, yt-dlp sanitised).
      final rawName = Uri.decodeComponent(
          streamed.headers['x-filename'] ?? '$videoId.mp3');
      // Strip any path separators that could escape outputDir.
      final safeName = rawName.replaceAll(RegExp(r'[\\/]'), '_');

      await Directory(outputDir).create(recursive: true);
      final outFile = File('$outputDir/$safeName');

      final totalBytes =
          int.tryParse(streamed.headers['content-length'] ?? '') ?? 0;
      int received = 0;

      final sink = outFile.openWrite();
      try {
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (totalBytes > 0) onProgress?.call(received / totalBytes);
        }
      } finally {
        await sink.close();
      }

      // Save thumbnail as sidecar .jpg
      if (thumbnailUrl.isNotEmpty) {
        try {
          final thumb = await http.get(Uri.parse(thumbnailUrl))
              .timeout(const Duration(seconds: 15));
          if (thumb.statusCode == 200) {
            final thumbPath = p.withoutExtension(outFile.path) + '.jpg';
            await File(thumbPath).writeAsBytes(thumb.bodyBytes);
          }
        } catch (_) {}
      }

      return outFile.path;
    } finally {
      client.close();
    }
  }
}
