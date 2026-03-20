import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../services/api_service.dart';          // ADD THIS
import '../providers/music_providers.dart';      // ADD THIS
import 'audius_service.dart';

class PlayerService {
  final AudioPlayer _player = AudioPlayer();
  final ApiService _api;

  PlayerService(this._api);

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get positionStream => _player.positionStream;

Future<void> playSong(Song song) async {
  try {
    print('=== PLAYING: ${song.title} ===');

    // Stop and reset player completely first
    await _player.stop();
    await _player.seek(Duration.zero);

    String url = song.url;

    // Check if Audius track
    if (song.id.startsWith('audius_')) {
      final audius = AudiusService();
      url = await audius.getStreamUrl(song.id);
    } else {
      // Always fetch fresh URL — never use cached
      url = await _api.getStreamUrl(song.id);
    }

    print('Stream URL: ${url.isNotEmpty ? "OK" : "EMPTY"}');

    if (url.isEmpty) {
      print('No stream URL found for ${song.id}');
      return;
    }

    // Set new URL and play
    await _player.setUrl(url, preload: true);
    await _player.play();
    print('Now playing: ${song.title}');

  } catch (e) {
    print('Player error: $e');
    // Try to recover
    try {
      await _player.stop();
    } catch (_) {}
  }
}

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}

// Provider
final playerServiceProvider = Provider<PlayerService>((ref) {
  final api = ref.read(apiServiceProvider);
  final service = PlayerService(api);
  ref.onDispose(() => service.dispose());
  return service;
});

// Is playing stream provider
final isPlayingStreamProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(playerServiceProvider).player;
  return player.playingStream;
});

// Position stream provider
final positionStreamProvider = StreamProvider<Duration>((ref) {
  return ref.watch(playerServiceProvider).positionStream;
});

// Duration stream provider
final durationStreamProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(playerServiceProvider).durationStream;
});