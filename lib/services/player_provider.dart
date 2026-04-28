import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../data/song_model.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  Song? get currentSong => _currentSong;
  List<Song> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;

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

  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    _currentSong = song;
    if (queue != null) _queue = List<Song>.from(queue);
    if (index != null) _currentIndex = index;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
    await _player.play(DeviceFileSource(song.filePath));
  }

  /// Add a song to the end of the current queue.
  void addToQueue(Song song) {
    _queue.add(song);
    notifyListeners();
  }

  /// Remove a song by queue index.
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (_currentIndex > index) {
      _currentIndex--;
    } else if (_currentIndex == index) {
      _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
    }
    notifyListeners();
  }

  /// Reorder queue (from ReorderableListView).
  void reorderQueue(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);
    // Keep _currentIndex pointing to the same song
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    notifyListeners();
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
    if (_queue.isEmpty || _currentIndex < 0) return;
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _queue.length) {
      // End of queue — stop
      await _player.stop();
      _isPlaying = false;
      notifyListeners();
      return;
    }
    await playSong(_queue[nextIndex], index: nextIndex);
  }

  Future<void> previous() async {
    if (_queue.isEmpty || _currentIndex < 0) return;
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      final prevIndex = (_currentIndex - 1).clamp(0, _queue.length - 1);
      await playSong(_queue[prevIndex], index: prevIndex);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
