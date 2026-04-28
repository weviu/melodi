import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

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
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
      if (state.processingState == ProcessingState.completed) {
        next();
      }
    });

    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    _currentSong = song;
    if (queue != null) _queue = List.unmodifiable(queue);
    if (index != null) _currentIndex = index;
    notifyListeners();
    await _player.setFilePath(song.filePath);
    await _player.play();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
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
