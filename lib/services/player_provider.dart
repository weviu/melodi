import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../data/song_model.dart';

enum LoopMode { off, loopPlaylist, loopSong }

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  Song? _currentSong;

  /// Songs explicitly added via "Add to Queue" — played before source continues.
  final List<Song> _manualQueue = [];

  /// The source context (library or playlist) for auto-continuation.
  List<Song> _source = [];
  int _sourceIndex = -1;
  String _sourceName = 'Library';

  /// Original source order before shuffle.
  List<Song> _originalSource = [];

  bool _isPlaying = false;
  bool _isShuffled = false;
  LoopMode _loopMode = LoopMode.off;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // ── Getters ────────────────────────────────────────────────────────────────

  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get isShuffled => _isShuffled;
  LoopMode get loopMode => _loopMode;
  Duration get position => _position;
  Duration get duration => _duration;
  String get sourceName => _sourceName;
  List<Song> get source => List.unmodifiable(_source);

  List<Song> get manualQueue => List.unmodifiable(_manualQueue);

  List<Song> get sourceUpcoming {
    if (_sourceIndex < 0 || _sourceIndex + 1 >= _source.length) return [];
    return List.unmodifiable(_source.sublist(_sourceIndex + 1));
  }

  /// Flat view of everything coming next (manual first, then source).
  List<Song> get upcomingQueue => [..._manualQueue, ...sourceUpcoming];

  // ── Constructor ────────────────────────────────────────────────────────────

  PlayerProvider() {
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
      if (state == PlayerState.completed) {
        next();
      }
    });
    _player.onPositionChanged.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _player.onDurationChanged.listen((dur) {
      _duration = dur;
      notifyListeners();
    });
  }

  // ── Playback ───────────────────────────────────────────────────────────────

  /// Start playing from a source (library or playlist) at a given index.
  Future<void> playFromSource(
    Song song, {
    required List<Song> source,
    required int index,
    String sourceName = 'Library',
  }) async {
    _source = List<Song>.from(source);
    _sourceIndex = index;
    _sourceName = sourceName;
    _manualQueue.clear();
    _isShuffled = false;
    _originalSource = [];
    await _playCurrent(song);
  }

  Future<void> _playCurrent(Song song) async {
    _currentSong = song;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
    await _player.play(DeviceFileSource(song.filePath));
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> next() async {
    // Loop song — restart current
    if (_loopMode == LoopMode.loopSong && _currentSong != null) {
      await _player.seek(Duration.zero);
      await _player.resume();
      return;
    }
    // 1. Manual queue has priority
    if (_manualQueue.isNotEmpty) {
      final song = _manualQueue.removeAt(0);
      await _playCurrent(song);
      return;
    }
    // 2. Advance source
    if (_sourceIndex + 1 < _source.length) {
      _sourceIndex++;
      await _playCurrent(_source[_sourceIndex]);
      return;
    }
    // 3. End of source
    if (_loopMode == LoopMode.loopPlaylist && _source.isNotEmpty) {
      _sourceIndex = 0;
      await _playCurrent(_source[0]);
      return;
    }
    // 4. Stop
    await _player.stop();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> previous() async {
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_sourceIndex > 0) {
      _sourceIndex--;
      await _playCurrent(_source[_sourceIndex]);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  // ── Queue management ───────────────────────────────────────────────────────

  void addToQueue(Song song) {
    _manualQueue.add(song);
    notifyListeners();
  }

  /// Remove from the combined upcoming list by index.
  void removeFromUpcoming(int combinedIndex) {
    final manualLen = _manualQueue.length;
    if (combinedIndex < manualLen) {
      _manualQueue.removeAt(combinedIndex);
    } else {
      final sourceOffset = combinedIndex - manualLen;
      final actualSourceIndex = _sourceIndex + 1 + sourceOffset;
      if (actualSourceIndex < _source.length) {
        _source.removeAt(actualSourceIndex);
      }
    }
    notifyListeners();
  }

  /// Reorder combined upcoming list.
  void reorderUpcoming(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final combined = upcomingQueue.toList();
    final item = combined.removeAt(oldIndex);
    combined.insert(newIndex, item);
    // After manual reorder, absorb everything into manual queue
    // and clear the source continuation (user has taken control)
    _manualQueue
      ..clear()
      ..addAll(combined);
    if (_sourceIndex >= 0) {
      _source = _source.sublist(0, _sourceIndex + 1);
    }
    notifyListeners();
  }

  /// Jump to a specific item in the upcoming queue and play it.
  Future<void> skipToUpcoming(int combinedIndex) async {
    final combined = upcomingQueue.toList();
    if (combinedIndex >= combined.length) return;
    final song = combined[combinedIndex];
    final remaining = combined.sublist(combinedIndex + 1);
    _manualQueue
      ..clear()
      ..addAll(remaining);
    if (_sourceIndex >= 0) {
      _source = _source.sublist(0, _sourceIndex + 1);
    }
    await _playCurrent(song);
  }

  void clearUpcoming() {
    _manualQueue.clear();
    if (_sourceIndex >= 0) {
      _source = _source.sublist(0, _sourceIndex + 1);
    }
    notifyListeners();
  }

  // ── Shuffle ────────────────────────────────────────────────────────────────

  void cycleLoopMode() {
    _loopMode = LoopMode.values[(_loopMode.index + 1) % LoopMode.values.length];
    notifyListeners();
  }

  void toggleShuffle() {
    if (_isShuffled) {
      // Restore original order, keep current song position
      if (_originalSource.isNotEmpty) {
        final currentPath = _currentSong?.filePath;
        _source = List<Song>.from(_originalSource);
        _sourceIndex =
            _source.indexWhere((s) => s.filePath == currentPath);
        if (_sourceIndex < 0) _sourceIndex = 0;
        _originalSource = [];
      }
      _isShuffled = false;
    } else {
      // Shuffle the upcoming source songs
      _originalSource = List<Song>.from(_source);
      final played = _source.sublist(0, _sourceIndex + 1);
      final upcoming = _source.sublist(_sourceIndex + 1)..shuffle();
      _source = [...played, ...upcoming];
      _isShuffled = true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
