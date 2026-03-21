import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../providers/music_providers.dart';
import '../providers/queue_meta.dart';
import 'database_service.dart';
import 'audius_service.dart';

class PlayerService {
  final AudioPlayer _player = AudioPlayer();
  final ApiService _api;
  final Ref _ref;
  bool _fetchingMore = false; // guard against duplicate fetches

  PlayerService(this._api, this._ref) {
    _initListener();
  }

  void _initListener() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        final playlist = _ref.read(currentPlaylistProvider);
        final index   = _ref.read(currentSongIndexProvider);

        // Handle repeat one
        final repeat = _ref.read(repeatModeProvider);
        if (repeat == RepeatMode.one) {
          _player.seek(Duration.zero);
          _player.play();
          return;
        }

        if (index + 1 < playlist.length) {
          _advanceTo(index + 1);
        } else {
          // End of queue — fetch smart continuation
          _fetchSmartQueue();
        }
      }
    });

    // Proactive prefetch: when 2 songs left, silently fetch more
    _player.positionStream.listen((_) {
      final playlist = _ref.read(currentPlaylistProvider);
      final index   = _ref.read(currentSongIndexProvider);
      final remaining = playlist.length - index - 1;
      if (remaining <= 2 && !_fetchingMore) {
        _fetchSmartQueue(prefetch: true);
      }
    });
  }

  void _advanceTo(int nextIndex) {
    final playlist = _ref.read(currentPlaylistProvider);
    if (playlist.isEmpty || nextIndex >= playlist.length) return;
    final nextSong = playlist[nextIndex];
    print('PLAYER: → [$nextIndex] ${nextSong.title}');
    _ref.read(currentSongIndexProvider.notifier).state = nextIndex;
    _ref.read(currentSongProvider.notifier).state      = nextSong;
    playSong(nextSong);
  }

  // Public skip — used by UI buttons and swipe
  void skipNext() {
    final playlist = _ref.read(currentPlaylistProvider);
    final index   = _ref.read(currentSongIndexProvider);
    if (playlist.isEmpty || index < 0) return;

    final isShuffle = _ref.read(isShuffleProvider);
    int nextIndex;
    if (isShuffle && playlist.length > 1) {
      final pool = List.generate(playlist.length, (i) => i)
        ..remove(index)..shuffle();
      nextIndex = pool.first;
    } else {
      nextIndex = (index + 1) % playlist.length;
    }
    _advanceTo(nextIndex);
  }

  void skipPrev() {
    final pos = _player.position;
    if (pos.inSeconds > 3) {
      _player.seek(Duration.zero);
      return;
    }
    final playlist = _ref.read(currentPlaylistProvider);
    final index   = _ref.read(currentSongIndexProvider);
    if (playlist.isEmpty || index < 0) return;
    final prevIndex = index == 0 ? playlist.length - 1 : index - 1;
    _advanceTo(prevIndex);
  }

  Future<void> _fetchSmartQueue({bool prefetch = false}) async {
    if (_fetchingMore) return;
    _fetchingMore = true;

    final current = _ref.read(currentSongProvider);
    if (current == null) { _fetchingMore = false; return; }

    final meta = _ref.read(queueMetaProvider);
    print('PLAYER: Smart queue fetch context=${meta.context} mood=${meta.mood} prefetch=$prefetch');

    List<Song> recs = [];
    try {
      switch (meta.context) {
        case QueueContext.mood:
          recs = meta.mood != null
              ? await _api.getMoodMix(meta.mood!)
              : await _api.getRecommendations(current);
          break;
        case QueueContext.artist:
          recs = await _api.getArtistSongs(meta.artistName ?? current.artist);
          break;
        case QueueContext.trending:
          recs = await _api.getTrending();
          break;
        case QueueContext.topCharts:
          recs = await _api.getTopCharts();
          break;
        case QueueContext.throwback:
          recs = await _api.getThrowback();
          break;
        case QueueContext.newReleases:
          recs = await _api.getNewReleases();
          break;
        case QueueContext.timeBased:
          recs = await _api.getTimeBased();
          break;
        case QueueContext.general:
        default:
          recs = await _api.getRecommendations(current);
          break;
      }
    } catch (e) {
      print('PLAYER: Smart queue error: $e');
      try { recs = await _api.getRecommendations(current); } catch (_) {}
    }

    if (recs.isEmpty) {
      try { recs = await _api.getRecommendations(current); } catch (_) {}
    }

    if (recs.isNotEmpty) {
      final existing    = _ref.read(currentPlaylistProvider);
      final existingIds = existing.map((s) => s.id).toSet();
      final fresh       = recs.where((s) => !existingIds.contains(s.id)).toList();

      if (fresh.isNotEmpty) {
        final newList = [...existing, ...fresh];
        // Write new playlist FIRST
        _ref.read(currentPlaylistProvider.notifier).state = newList;
        print('PLAYER: +\${fresh.length} songs added to queue.');

        // Only auto-advance if at actual end (not a background prefetch)
        if (!prefetch) {
          final idx     = _ref.read(currentSongIndexProvider);
          final nextIdx = idx + 1;
          // Use newList directly — provider may not have flushed yet
          if (nextIdx < newList.length) {
            final nextSong = newList[nextIdx];
            print('PLAYER: Auto-play [\$nextIdx] \${nextSong.title}');
            _ref.read(currentSongIndexProvider.notifier).state = nextIdx;
            _ref.read(currentSongProvider.notifier).state      = nextSong;
            await Future.delayed(const Duration(milliseconds: 80));
            await playSong(nextSong);
          }
        }
      }
    }

    _fetchingMore = false;
  }

  // ─── PUBLIC API ───────────────────────────────────────────────

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?>  get durationStream     => _player.durationStream;
  Stream<Duration>   get positionStream     => _player.positionStream;

  Future<void> playSong(Song song) async {
    print('=== PLAYING: ${song.title} ===');
    try {
      await _player.pause();

      String url = song.url;
      if (song.id.startsWith('audius_')) {
        url = await AudiusService().getStreamUrl(song.id);
      } else {
        url = await _api.getStreamUrl(song.id);
      }

      if (url.isEmpty) {
        print('PLAYER: No URL — skipping');
        // Auto-skip broken tracks
        final idx = _ref.read(currentSongIndexProvider);
        final pl  = _ref.read(currentPlaylistProvider);
        if (idx + 1 < pl.length) _advanceTo(idx + 1);
        return;
      }

      await _player.setUrl(url, initialPosition: Duration.zero, preload: true);
      await _player.play();
      print('PLAYER: ▶ ${song.title}');

      _ref.read(databaseServiceProvider).addToHistory(song);
    } catch (e, st) {
      print('PLAYER: Error: $e\n$st');
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        await _player.stop();
      } catch (_) {}
    }
  }

  Future<void> togglePlayPause() async {
    _player.playing ? await _player.pause() : await _player.play();
  }

  Future<void> seekTo(Duration position) async => _player.seek(position);
  Future<void> stop() async => _player.stop();
  void dispose() => _player.dispose();
}

// ─── PROVIDERS ────────────────────────────────────────────────

// Expose these so player_screen can call skipNext/skipPrev on the service
final repeatModeProvider  = StateProvider<RepeatMode>((ref) => RepeatMode.off);
final isShuffleProvider   = StateProvider<bool>((ref) => false);
enum RepeatMode { off, all, one }

final playerServiceProvider = Provider<PlayerService>((ref) {
  final service = PlayerService(ref.read(apiServiceProvider), ref);
  ref.onDispose(() => service.dispose());
  return service;
});

final isPlayingStreamProvider = StreamProvider<bool>((ref) =>
    ref.watch(playerServiceProvider).player.playingStream);

final positionStreamProvider = StreamProvider<Duration>((ref) =>
    ref.watch(playerServiceProvider).positionStream);

final durationStreamProvider = StreamProvider<Duration?>((ref) =>
    ref.watch(playerServiceProvider).durationStream);