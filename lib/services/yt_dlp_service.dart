import 'dart:convert';
import 'dart:io';

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
  /// Search YouTube and return up to [maxResults] results.
  Future<List<YtSearchResult>> search(String query,
      {int maxResults = 20}) async {
    final result = await Process.run('yt-dlp', [
      'ytsearch$maxResults:$query',
      '--flat-playlist',
      '--dump-single-json',
      '--no-warnings',
      '--quiet',
    ]);

    if (result.exitCode != 0) {
      throw Exception('yt-dlp search failed: ${result.stderr}');
    }

    final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final entries = (json['entries'] as List? ?? []);

    return entries.map((e) {
      final durationSec = (e['duration'] as num?)?.toInt() ?? 0;
      final mins = (durationSec ~/ 60).toString().padLeft(2, '0');
      final secs = (durationSec % 60).toString().padLeft(2, '0');
      return YtSearchResult(
        id: e['id'] as String? ?? '',
        title: e['title'] as String? ?? 'Unknown',
        channel: e['channel'] as String? ?? e['uploader'] as String? ?? '',
        duration: '$mins:$secs',
        thumbnailUrl: e['thumbnail'] as String? ?? '',
      );
    }).toList();
  }

  /// Download [videoId] as MP3 into [outputDir].
  /// Calls [onProgress] with lines from yt-dlp's stdout.
  /// Returns the path to the downloaded MP3.
  Future<String> downloadMp3(
    String videoId,
    String outputDir, {
    void Function(String line)? onProgress,
  }) async {
    final process = await Process.start('yt-dlp', [
      'https://www.youtube.com/watch?v=$videoId',
      '--extract-audio',
      '--audio-format', 'mp3',
      '--audio-quality', '0',
      '--embed-thumbnail',
      '--add-metadata',
      '--output', '$outputDir/%(title)s.%(ext)s',
      '--no-playlist',
      '--newline',
    ]);

    String? outputPath;

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      onProgress?.call(line);
      // yt-dlp prints "[ExtractAudio] Destination: /path/to/file.mp3"
      if (line.contains('[ExtractAudio] Destination:')) {
        outputPath = line.split('Destination:').last.trim();
      }
      // Also catch "[download] Destination: ..." for direct mp3 streams
      if (line.startsWith('[download] Destination:') &&
          line.endsWith('.mp3')) {
        outputPath = line.split('Destination:').last.trim();
      }
    });

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => onProgress?.call(line));

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception('yt-dlp download failed (exit $exitCode)');
    }

    return outputPath ?? outputDir;
  }
}
