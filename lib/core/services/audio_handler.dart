// ─────────────────────────────────────────────────────────────────────────────
// audio_handler.dart  —  DEN Background Audio Handler
//
// Powers:
//   • Spotify-style media notification (notification bar)
//   • Lock screen player with album art + controls
//   • Works when app is minimised or screen is off
//   • Headset / Bluetooth button support
//   • Seek bar in notification
//
// lib/core/services/audio_handler.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

// Global instance — initialised in main.dart before runApp()
late AudioHandler audioHandler;

// ── Song → MediaItem ─────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
class DenAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {

  final AudioPlayer _player;

  VoidCallback? _onSkipNext;
  VoidCallback? _onSkipPrev;
  VoidCallback? _onToggle;

  AudioPlayer get player => _player;

  DenAudioHandler({
    required AudioPlayer player,
    required VoidCallback onSkipNext,
    required VoidCallback onSkipPrev,
    required VoidCallback onTogglePlayPause,
  }) : _player = player {
    _onSkipNext = onSkipNext;
    _onSkipPrev = onSkipPrev;
    _onToggle   = onTogglePlayPause;
    _listenToPlayer();
  }

  // ── Called by PlayerService after it's created ───────────────────────────
  void setCallbacks({
    required VoidCallback onSkipNext,
    required VoidCallback onSkipPrev,
    required VoidCallback onToggle,
  }) {
    _onSkipNext = onSkipNext;
    _onSkipPrev = onSkipPrev;
    _onToggle   = onToggle;
  }

  // ── Called every time a new song starts ──────────────────────────────────
  void updateNowPlaying(Song song) {
    mediaItem.add(_songToMediaItem(song));
    _broadcastState(); // refresh notification immediately
  }

  // ── Push current state to the OS ─────────────────────────────────────────
  void _broadcastState() {
    final playing = _player.playing;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.playPause,
          MediaAction.stop,
        },
        // prev=0  play/pause=1  next=2  → shown in compact notification
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapState(),
        playing:          playing,
        updatePosition:   _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed:            _player.speed,
      ),
    );
  }

  void _listenToPlayer() {
    // Fires on every play/pause/seek/buffer change → keeps notification fresh
    _player.playbackEventStream.listen((_) => _broadcastState());

    // Update duration in MediaItem once the stream knows it
    _player.durationStream.listen((d) {
      final cur = mediaItem.value;
      if (cur != null && d != null) {
        mediaItem.add(cur.copyWith(duration: d));
      }
    });
  }

  AudioProcessingState _mapState() {
    switch (_player.processingState) {
      case ProcessingState.idle:      return AudioProcessingState.idle;
      case ProcessingState.loading:   return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready:     return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
    }
  }

  // ── AudioHandler overrides ────────────────────────────────────────────────
  @override Future<void> play()  async => _player.play();
  @override Future<void> pause() async => _player.pause();
  @override Future<void> stop()  async {
    await _player.stop();
    await super.stop();
  }
  @override Future<void> seek(Duration position) async =>
      _player.seek(position);

  @override
  Future<void> skipToNext() async => _onSkipNext?.call();

  @override
  Future<void> skipToPrevious() async => _onSkipPrev?.call();

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:    _onToggle?.call();   break;
      case MediaButton.next:     _onSkipNext?.call(); break;
      case MediaButton.previous: _onSkipPrev?.call(); break;
    }
  }

  @override
  Future<void> setSpeed(double speed) async => _player.setSpeed(speed);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode _) async {}

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode _) async {}
}