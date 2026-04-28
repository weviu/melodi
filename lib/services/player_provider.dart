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
  List<Song> get queue => _queue;
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
    if (queue != null) _queue = List.unmodifiable(queue);
    if (index != null) _currentIndex = index;
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
    if (_queue.isEmpty || _currentIndex < 0) return;
    final nextIndex = (_currentIndex + 1) % _queue.length;
    await playSong(_queue[nextIndex], index: nextIndex);
  }

  Future<void> previous() async {
    if (_queue.isEmpty || _currentIndex < 0) return;
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      final prevIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
      await playSong(_queue[prevIndex], index: prevIndex);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
