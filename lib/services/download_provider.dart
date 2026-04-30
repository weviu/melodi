import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../services/scanner_service.dart';
import '../services/yt_dlp_service.dart';

enum DownloadStatus { idle, downloading, done, error }

class DownloadState {
  final DownloadStatus status;
  final double progress; // 0.0 – 1.0
  final String? lastLine;
  final String? error;

  const DownloadState({
    this.status = DownloadStatus.idle,
    this.progress = 0,
    this.lastLine,
    this.error,
  });

  DownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? lastLine,
    String? error,
  }) =>
      DownloadState(
        status: status ?? this.status,
        progress: progress ?? this.progress,
        lastLine: lastLine ?? this.lastLine,
        error: error ?? this.error,
      );
}

class DownloadProvider extends ChangeNotifier {
  final _ytDlp = YtDlpService();
  final _scanner = ScannerService();
  final _db = DatabaseHelper();

  /// Map of videoId → state
  final Map<String, DownloadState> _states = {};

  DownloadState stateFor(String videoId) =>
      _states[videoId] ?? const DownloadState();

  bool get hasActiveDownloads =>
      _states.values.any((s) => s.status == DownloadStatus.downloading);

  /// Queue for bulk downloads
  final List<_QueuedDownload> _queue = [];
  bool _processingQueue = false;

  Future<void> download(String videoId, String outputDir,
      {String thumbnailUrl = '', VoidCallback? onLibraryChanged}) async {
    _setState(videoId, const DownloadState(status: DownloadStatus.downloading));

    try {
      await _ytDlp.downloadMp3(videoId, outputDir,
          thumbnailUrl: thumbnailUrl,
          onProgress: (p) {
        _setState(videoId, _states[videoId]!.copyWith(progress: p));
      });

      // Re-scan and update DB first, then mark done so listeners see fresh data
      final songs = await _scanner.scanDirectory(outputDir);
      await _db.clearSongs();
      await _db.insertSongs(songs);
      onLibraryChanged?.call();
      _setState(videoId,
          const DownloadState(status: DownloadStatus.done, progress: 1.0));
    } catch (e) {
      _setState(
        videoId,
        DownloadState(status: DownloadStatus.error, error: e.toString()),
      );
    }
  }

  void enqueueBulk(List<String> videoIds, String outputDir,
      {Map<String, String> thumbnailUrls = const {},
      VoidCallback? onLibraryChanged}) {
    for (final id in videoIds) {
      if (stateFor(id).status != DownloadStatus.downloading &&
          stateFor(id).status != DownloadStatus.done) {
        _queue.add(_QueuedDownload(
            videoId: id,
            outputDir: outputDir,
            thumbnailUrl: thumbnailUrls[id] ?? '',
            onLibraryChanged: onLibraryChanged));
        _setState(id, const DownloadState(status: DownloadStatus.downloading));
      }
    }
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_processingQueue) return;
    _processingQueue = true;
    while (_queue.isNotEmpty) {
      final item = _queue.removeAt(0);
      await download(item.videoId, item.outputDir,
          thumbnailUrl: item.thumbnailUrl,
          onLibraryChanged: item.onLibraryChanged);
    }
    _processingQueue = false;
  }

  void _setState(String videoId, DownloadState state) {
    _states[videoId] = state;
    notifyListeners();
  }

}

class _QueuedDownload {
  final String videoId;
  final String outputDir;
  final String thumbnailUrl;
  final VoidCallback? onLibraryChanged;
  _QueuedDownload(
      {required this.videoId,
      required this.outputDir,
      this.thumbnailUrl = '',
      this.onLibraryChanged});
}
