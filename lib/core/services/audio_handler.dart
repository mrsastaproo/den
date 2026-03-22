// ─────────────────────────────────────────────────────────────────────────────
// audio_handler.dart  —  DEN Background Audio Handler
//
// Bridges just_audio ↔ Android MediaSession / iOS Now Playing.
//
// What this gives you:
//   • Media notification in notification bar with album art
//   • Lock screen controls (play/pause/skip)
//   • Works when app is minimised or screen is off
//   • Headset button support
//
// Wire-up:
//   1. AudioService.init() called in main.dart before runApp()
//   2. PlayerService calls audioHandler.updateNowPlaying() on each new song
//   3. PlayerService registers skip/toggle callbacks via setCallbacks()
//
// lib/core/services/audio_handler.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart'; // Required for VoidCallback
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

// Global instance initialised in main.dart
late AudioHandler audioHandler;

// Convert Song → MediaItem
MediaItem _songToMediaItem(Song song) => MediaItem(
  id:     song.id,
  title:  song.title,
  artist: song.artist,
  album:  song.album.isNotEmpty ? song.album : 'DEN',
  artUri: song.image.isNotEmpty ? Uri.parse(song.image) : null,
  duration: song.duration.isNotEmpty
      ? Duration(seconds: int.tryParse(song.duration) ?? 0)
      : null,
);

class DenAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {

  final AudioPlayer _player;

  // Callbacks wired in by PlayerService after it's created
  VoidCallback? _onSkipNext;
  VoidCallback? _onSkipPrev;
  VoidCallback? _onToggle;

  DenAudioHandler({
    required AudioPlayer player,
    required VoidCallback onSkipNext,
    required VoidCallback onSkipPrev,
    required VoidCallback onTogglePlayPause,
  }) : _player = player {
    _onSkipNext = onSkipNext;
    _onSkipPrev = onSkipPrev;
    _onToggle = onTogglePlayPause;
    _listenToPlayer();
  }

  // Called by PlayerService constructor to update controls
  void setCallbacks({
    required VoidCallback onSkipNext,
    required VoidCallback onSkipPrev,
    required VoidCallback onToggle,
  }) {
    _onSkipNext = onSkipNext;
    _onSkipPrev = onSkipPrev;
    _onToggle   = onToggle;
  }

  // Called every time a new song starts playing
  void updateNowPlaying(Song song) {
    mediaItem.add(_songToMediaItem(song));
  }

  void _listenToPlayer() {
    _player.playbackEventStream.listen((_) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _processingState(),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });

    _player.durationStream.listen((d) {
      final cur = mediaItem.value;
      if (cur != null && d != null) {
        mediaItem.add(cur.copyWith(duration: d));
      }
    });
  }

  AudioProcessingState _processingState() {
    switch (_player.processingState) {
      case ProcessingState.idle:      return AudioProcessingState.idle;
      case ProcessingState.loading:   return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready:     return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
    }
  }

  @override Future<void> play()  async => _player.play();
  @override Future<void> pause() async => _player.pause();
  @override Future<void> stop()  async { await _player.stop(); await super.stop(); }
  @override Future<void> seek(Duration position) async => _player.seek(position);

  @override
  Future<void> skipToNext() async => _onSkipNext?.call();

  @override
  Future<void> skipToPrevious() async => _onSkipPrev?.call();

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:    _onToggle?.call(); break;
      case MediaButton.next:     _onSkipNext?.call(); break;
      case MediaButton.previous: _onSkipPrev?.call(); break;
    }
  }
}