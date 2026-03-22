import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../providers/music_providers.dart';
import '../providers/queue_meta.dart';
import 'database_service.dart';
import 'audius_service.dart';
import 'dart:io';

void _log(String msg) {
  print(msg);
  try {
    final f = File('c:\\Users\\Sanjeev\\den\\player_logs.txt');
    f.writeAsStringSync('${DateTime.now().toIso8601String()}: $msg\n', mode: FileMode.append);
  } catch (_) {}
}

class PlayerService {
  final AudioPlayer _player = AudioPlayer();
  final ApiService _api;
  final Ref _ref;
  final AudiusService _audius = AudiusService(); // single instance — not recreated per song
  bool _fetchingMore = false; // guard against duplicate fetches
  bool _loadingNext  = false; // guard against rapid automatic skips
  int _consecutiveSkips = 0; // prevent infinite auto-skip loops on errors

  PlayerService(this._api, this._ref) {
    _initListener();
  }

  void _initListener() {
    _player.playerStateStream.listen((state) {
      _log('Player state: ${state.processingState}, playing=${state.playing}');
      if (state.processingState == ProcessingState.completed) {
        _log('completed listener: _loadingNext=$_loadingNext');
        if (_loadingNext) return;
        // Ignore spurious completion fired during track loading
        if (_player.position == Duration.zero && !_player.playing) return;
        _loadingNext = true;
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

    // Proactive prefetch: when 2 songs left, silently fetch more.
    // Uses a flag to fire only once per crossing, not every tick.
    _player.positionStream.listen((_) {
      final playlist  = _ref.read(currentPlaylistProvider);
      final index     = _ref.read(currentSongIndexProvider);
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
    _log('PLAYER: → [$nextIndex] ${nextSong.title}');
    _ref.read(currentSongIndexProvider.notifier).state = nextIndex;
    _ref.read(currentSongProvider.notifier).state      = nextSong;
    playSong(nextSong);
  }

  // Public skip — used by UI buttons and swipe
  void skipNext() {
    // ── Reset all guards on every manual skip ──────────────────
    _loadingNext     = true;
    _consecutiveSkips = 0;
    _fetchingMore    = false;

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
    // ── Reset all guards on every manual skip ──────────────────
    _loadingNext     = true;
    _consecutiveSkips = 0;
    _fetchingMore    = false;

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
              : await _getSimilarSongs(current);
          break;
        case QueueContext.artist:
          recs = await _api.getArtistSongs(
              meta.artistName ?? current.artist);
          if (recs.isEmpty) recs = await _getSimilarSongs(current);
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
          // If the current song came from Audius search, use genre-based autoplay.
          // The genre is stored in song.language (set by _trackToSong in AudiusService).
          if (current.id.startsWith('audius_')) {
            final genre = current.language.isNotEmpty ? current.language : 'all';
            print('PLAYER: Audius genre autoplay → genre=$genre');
            recs = await _audius.fetchByGenre(genre, limit: 30, excludeId: current.id);
            // Fallback: if genre fetch returns nothing, use Audius trending
            if (recs.isEmpty) recs = await _audius.getTrending(limit: 20);
          } else {
            // Non-Audius song — use existing similar-song logic
            recs = await _getSimilarSongs(current);
          }
          break;
      }
    } catch (e) {
      print('PLAYER: Smart queue error: $e');
    }

    // Fallback chain
    if (recs.isEmpty) {
      try { recs = await _api.getRecommendations(current); } catch (_) {}
    }
    if (recs.isEmpty) {
      try { recs = await _api.getTrending(); } catch (_) {}
    }

    final existing    = _ref.read(currentPlaylistProvider);
    final existingIds = existing.map((s) => s.id).toSet();
    final fresh       = recs
        .where((s) => !existingIds.contains(s.id))
        .toList();

    if (fresh.isNotEmpty) {
      final newList = [...existing, ...fresh];
      _ref.read(currentPlaylistProvider.notifier).state = newList;
      print('PLAYER: +${fresh.length} songs added to queue.');

      if (!prefetch) {
        final idx     = _ref.read(currentSongIndexProvider);
        final nextIdx = idx + 1;
        if (nextIdx < newList.length) {
          final nextSong = newList[nextIdx];
          print('PLAYER: Auto-play [$nextIdx] ${nextSong.title}');
          _ref.read(currentSongIndexProvider.notifier).state = nextIdx;
          _ref.read(currentSongProvider.notifier).state      = nextSong;
          _fetchingMore = false; // reset BEFORE playing
          await Future.delayed(const Duration(milliseconds: 80));
          await playSong(nextSong);
          return;
        }
      }
    } else if (!prefetch) {
      // fresh is empty — all recs already in queue.
      // Just advance if there are songs ahead.
      final idx = _ref.read(currentSongIndexProvider);
      final pl  = _ref.read(currentPlaylistProvider);
      if (idx + 1 < pl.length) {
        _fetchingMore = false;
        _advanceTo(idx + 1);
        return;
      }
      _loadingNext = false;  // Reset guard if queue cannot continue
      _fetchingMore = false; // BUG FIX: was missing — caused permanent stall
    }

    _fetchingMore = false;
  }

  /// Gets songs genuinely similar to [song] by firing multiple
  /// targeted queries in parallel — artist + language + recommendations.
  Future<List<Song>> _getSimilarSongs(Song song) async {
    final artist      = song.artist.isNotEmpty ? song.artist : '';
    final lang        = song.language.isNotEmpty &&
            song.language.toLowerCase() != 'unknown'
        ? song.language
        : '';
    final searchQuery = _ref.read(queueMetaProvider).searchQuery ?? '';

    final futures = <Future<List<Song>>>[
      _api.getRecommendations(song),
    ];

    if (artist.isNotEmpty) {
      futures.add(_api.searchSongs('$artist songs', page: 1));
      futures.add(_api.getArtistSongs(artist));
    }

    if (lang.isNotEmpty) {
      futures.add(_api.searchSongs('best $lang songs', page: 1));
    }

    // If the user searched for something specific (e.g. "phonk"),
    // keep finding more of that same vibe
    if (searchQuery.isNotEmpty && searchQuery.toLowerCase() != song.title.toLowerCase()) {
      futures.add(_api.searchSongs(searchQuery, page: 2));
      futures.add(_api.searchSongs(searchQuery, page: 3));
    }

    final results = await Future.wait(futures);

    final seen = <String>{};
    final all  = results
        .expand((l) => l)
        .where((s) => seen.add(s.id) && s.id != song.id)
        .toList();

    all.shuffle();
    return all;
  }

  // ─── PUBLIC API ───────────────────────────────────────────────

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?>  get durationStream     => _player.durationStream;
  Stream<Duration>   get positionStream     => _player.positionStream;

  Future<void> playSong(Song song) async {
    _log('=== PLAYING: ${song.title} ===');
    try {
      await _player.stop(); // stop clears completed state; pause does not

      String url = song.url;
      if (song.id.startsWith('audius_')) {
        url = await _audius.getStreamUrl(song.id); // use shared instance, not new AudiusService()
      } else {
        url = await _api.getStreamUrl(song.id);
      }

      if (url.isEmpty) {
        _log('PLAYER: No URL — skipping ${song.title}');
        if (_consecutiveSkips >= 3) {
          _log('PLAYER: Max consecutive skips reached. Stopping advance loop.');
          _consecutiveSkips = 0;
          _loadingNext = false;
          return;
        }
        _consecutiveSkips++;
        final idx = _ref.read(currentSongIndexProvider);
        final pl  = _ref.read(currentPlaylistProvider);
        if (idx + 1 < pl.length) {
          _advanceTo(idx + 1);
        } else {
          _loadingNext = false; // Reset guard if queue ends
          _fetchSmartQueue();
        }
        return;
      }

      await _player.setUrl(url, initialPosition: Duration.zero, preload: true);
      _consecutiveSkips = 0; // Reset counter on successful load
      _loadingNext = false; // Reset guard after successful load
      await _player.play();
      print('PLAYER: ▶ ${song.title}');

      _ref.read(databaseServiceProvider).addToHistory(song);
    } catch (e, st) {
      _log('PLAYER: Error playing ${song.title}: $e');
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        await _player.stop();
      } catch (_) {}

      if (_consecutiveSkips >= 3) {
        _log('PLAYER: Max consecutive skips reached in error handler. Stopping advance loop.');
        _consecutiveSkips = 0;
        _loadingNext = false;
        return;
      }
      _consecutiveSkips++;

      // Auto-skip on error
      final idx = _ref.read(currentSongIndexProvider);
      final pl  = _ref.read(currentPlaylistProvider);
      if (idx + 1 < pl.length) {
        _advanceTo(idx + 1);
      } else {
        _loadingNext = false; // Reset guard if queue ends
        _fetchSmartQueue();
      }
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