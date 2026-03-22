import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../providers/music_providers.dart';
import '../providers/queue_meta.dart';
import 'database_service.dart';
import 'audius_service.dart';
import 'download_service.dart';
import 'settings_service.dart';
import 'audio_handler.dart';

void _log(String msg) => print('[DEN] $msg');

// ═══════════════════════════════════════════════════════════════
// SKIP ARCHITECTURE
//
// _doSkip  → _loadAndPlay → stop + fetchURL + setUrl → _commitUI → play
//
// _commitUI is the ONLY place that writes currentSongProvider
// and currentSongIndexProvider. Nowhere else.
//
// UI shows the new song IMMEDIATELY (optimistic update in _doSkip)
// but audio only starts after URL is confirmed. This gives Spotify-
// level feel: artwork/title change instantly, audio follows.
// ═══════════════════════════════════════════════════════════════

class PlayerService {
  final AudioPlayer   _player = AudioPlayer();
  final ApiService    _api;
  final Ref           _ref;
  final AudiusService _audius = AudiusService();

  bool _skipInProgress  = false;
  int  _consecutiveErrors = 0;
  DateTime? _lastPrefetchAt;

  bool     _crossfadeEnabled  = false;
  Duration _crossfadeDuration = const Duration(seconds: 3);
  bool     _gaplessEnabled    = true;

  PlayerService(this._api, this._ref) {
    _initListeners();
    // Register lock screen / notification button callbacks
    // after the service is created
    try {
      (audioHandler as DenAudioHandler).setCallbacks(
        onSkipNext: skipNext,
        onSkipPrev: skipPrev,
        onToggle:   togglePlayPauseSync,
      );
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // LISTENERS
  // ─────────────────────────────────────────────────────────────

  void _initListeners() {
    _player.playerStateStream.listen((state) {
      _ref.read(isPlayingProvider.notifier).state = state.playing;

      if (state.processingState == ProcessingState.completed) {
        // Never auto-advance during a manual skip
        if (_skipInProgress) return;

        _log('Track completed → auto advance');
        _autoAdvance();
      }
    });

    // Background prefetch — max once per 10s
    _player.positionStream.listen((pos) {
      if (pos.inSeconds < 5) return;
      if (_skipInProgress) return;

      final playlist  = _ref.read(currentPlaylistProvider);
      final idx       = _ref.read(currentSongIndexProvider) ?? 0;
      final remaining = playlist.length - idx - 1;

      if (remaining <= 2) {
        final now = DateTime.now();
        if (_lastPrefetchAt != null &&
            now.difference(_lastPrefetchAt!).inSeconds < 10) return;
        _lastPrefetchAt = now;
        _fetchSmartQueue(prefetch: true);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // AUTO ADVANCE
  // ─────────────────────────────────────────────────────────────

  void _autoAdvance() {
    if (_ref.read(repeatModeProvider) == RepeatMode.one) {
      _player.seek(Duration.zero).then((_) => _player.play());
      return;
    }
    final playlist = _ref.read(currentPlaylistProvider);
    final idx      = _ref.read(currentSongIndexProvider) ?? 0;
    if (idx + 1 < playlist.length) {
      _doSkip(playlist[idx + 1], idx + 1);
    } else {
      _fetchSmartQueue();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // _doSkip — THE ONLY SKIP ENTRY POINT
  //
  // Step 1: Immediately update UI (optimistic) so artwork/title
  //         changes feel instant like Spotify.
  // Step 2: Load audio in background.
  // Step 3: If audio fails, revert UI to previous song.
  // ─────────────────────────────────────────────────────────────

  void _doSkip(Song song, int index) {
    if (_skipInProgress) {
      _log('Skip ignored — busy');
      return;
    }
    _skipInProgress = true;

    // ── OPTIMISTIC UI UPDATE ─────────────────────────────────
    // Show new song instantly (title, artwork, palette).
    // Audio loads in background. If it fails, we revert.
    final prevSong  = _ref.read(currentSongProvider);
    final prevIndex = _ref.read(currentSongIndexProvider) ?? 0;
    _ref.read(currentSongIndexProvider.notifier).state = index;
    _ref.read(currentSongProvider.notifier).state      = song;

    _loadAndPlay(song, index, prevSong: prevSong, prevIndex: prevIndex)
        .whenComplete(() {
      _skipInProgress = false;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // _loadAndPlay — fetch URL and play
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadAndPlay(
    Song song,
    int index, {
    Song? prevSong,
    int prevIndex = 0,
  }) async {
    _log('Loading: ${song.title}');
    try {
      // CRITICAL: use stop() not pause() before loading a new source.
      // pause() leaves just_audio in its current processing state.
      // If the previous track just completed, the player is in
      // ProcessingState.completed — calling setUrl() from that state
      // does NOT reset it properly, so play() silently does nothing.
      // stop() fully resets the player to idle before loading new source.
      await _player.stop();

      final dl = _ref.read(downloadServiceProvider);

      if (await dl.isDownloaded(song.id)) {
        // ── Offline copy ──────────────────────────────────────
        final path = await dl.getDownloadPath(song.id);
        _log('Offline: $path');
        await _player.setAudioSource(
          AudioSource.uri(Uri.file(path)),
          initialPosition: Duration.zero,
          preload: true,
        );
      } else {
        // ── Stream URL ────────────────────────────────────────
        if (_ref.read(offlineModeProvider)) {
          _log('Offline mode — skipping ${song.title}');
          _handleError(song, index, prevSong: prevSong, prevIndex: prevIndex);
          return;
        }

        _log('Fetching URL for ${song.title}…');
        final url = song.id.startsWith('audius_')
            ? await _audius.getStreamUrl(song.id)
            : await _api.getStreamUrl(song.id);

        if (url.isEmpty) {
          _log('No URL — skipping ${song.title}');
          _handleError(song, index, prevSong: prevSong, prevIndex: prevIndex);
          return;
        }

        _log('URL ok, setting source…');
        await _player.setUrl(
          url,
          initialPosition: Duration.zero,
          preload: true,
        );
      }

      // ── Success ───────────────────────────────────────────
      _consecutiveErrors = 0;
      await _player.play();
      _log('▶ ${song.title}');

      // Update system media notification (lock screen / notification bar)
      try {
        (audioHandler as DenAudioHandler).updateNowPlaying(song);
      } catch (_) {}

      final isPrivate = _ref.read(privateSessionProvider);
      if (!isPrivate) {
        _ref.read(databaseServiceProvider).addToHistory(song);
      }

    } catch (e) {
      _log('Error loading ${song.title}: $e');
      try { await _player.stop(); } catch (_) {}
      _handleError(song, index, prevSong: prevSong, prevIndex: prevIndex);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ERROR HANDLER
  // Reverts UI to previous song if this is the FIRST error.
  // Auto-skips to next on repeated errors.
  // ─────────────────────────────────────────────────────────────

  void _handleError(
    Song song,
    int index, {
    Song? prevSong,
    int prevIndex = 0,
  }) {
    if (_consecutiveErrors == 0 && prevSong != null) {
      // First failure — revert UI to previous song so user
      // doesn't see a wrong song displayed with no audio.
      _ref.read(currentSongIndexProvider.notifier).state = prevIndex;
      _ref.read(currentSongProvider.notifier).state      = prevSong;
    }

    if (_consecutiveErrors >= 3) {
      _log('3 consecutive errors — stopping');
      _consecutiveErrors = 0;
      return;
    }
    _consecutiveErrors++;

    // Try next song
    final playlist = _ref.read(currentPlaylistProvider);
    final next     = index + 1;
    if (next < playlist.length) {
      _loadAndPlay(playlist[next], next);
    } else {
      _fetchSmartQueue();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────

  void skipNext() {
    HapticFeedback.selectionClick();
    final playlist = _ref.read(currentPlaylistProvider);
    final idx      = _ref.read(currentSongIndexProvider) ?? 0;
    if (playlist.isEmpty) return;

    _consecutiveErrors = 0;
    _skipInProgress    = false; // force-release so button always works

    final isShuffle = _ref.read(isShuffleProvider);
    final int next;
    if (isShuffle && playlist.length > 1) {
      final pool = List.generate(playlist.length, (i) => i)
        ..remove(idx)..shuffle();
      next = pool.first;
    } else {
      next = (idx + 1) % playlist.length;
    }
    _doSkip(playlist[next], next);
  }

  void skipPrev() {
    HapticFeedback.selectionClick();
    _consecutiveErrors = 0;

    if (_player.position.inSeconds > 3) {
      _player.seek(Duration.zero).then((_) => _player.play());
      return;
    }

    final playlist = _ref.read(currentPlaylistProvider);
    final idx      = _ref.read(currentSongIndexProvider) ?? 0;
    if (playlist.isEmpty) return;

    final prev = idx <= 0 ? playlist.length - 1 : idx - 1;
    _skipInProgress = false; // force-release
    _doSkip(playlist[prev], prev);
  }

  /// Called by PageView swipe and queue panel tap
  void requestPlay(Song song, int index) {
    _consecutiveErrors = 0;
    _skipInProgress    = false; // user intent always wins
    _doSkip(song, index);
  }

  /// Backward compat for playQueue() in music_providers.dart
  Future<void> playSong(Song song, {int? confirmedIndex}) async {
    final playlist = _ref.read(currentPlaylistProvider);
    final index    = confirmedIndex ??
        playlist.indexWhere((s) => s.id == song.id);
    requestPlay(song, index >= 0 ? index : 0);
  }

  // ─────────────────────────────────────────────────────────────
  // SMART QUEUE
  // ─────────────────────────────────────────────────────────────

  Future<void> _fetchSmartQueue({bool prefetch = false}) async {
    final current = _ref.read(currentSongProvider);
    if (current == null) return;

    final meta = _ref.read(queueMetaProvider);
    _log('Smart queue fetch — prefetch=$prefetch');

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
        case QueueContext.trending:    recs = await _api.getTrending();    break;
        case QueueContext.topCharts:   recs = await _api.getTopCharts();   break;
        case QueueContext.throwback:   recs = await _api.getThrowback();   break;
        case QueueContext.newReleases: recs = await _api.getNewReleases(); break;
        case QueueContext.timeBased:   recs = await _api.getTimeBased();   break;
        default:
          if (current.id.startsWith('audius_')) {
            final genre = current.language.isNotEmpty
                ? current.language : 'all';
            recs = await _audius.fetchByGenre(
                genre, limit: 30, excludeId: current.id);
            if (recs.isEmpty) recs = await _audius.getTrending(limit: 20);
          } else {
            recs = await _getSimilarSongs(current);
          }
      }
    } catch (e) { _log('Smart queue error: $e'); }

    if (recs.isEmpty) {
      try { recs = await _api.getRecommendations(current); } catch (_) {}
    }
    if (recs.isEmpty) {
      try { recs = await _api.getTrending(); } catch (_) {}
    }

    final existing    = _ref.read(currentPlaylistProvider);
    final existingIds = existing.map((s) => s.id).toSet();
    final fresh = recs.where((s) => !existingIds.contains(s.id)).toList();

    if (fresh.isNotEmpty) {
      final newList = [...existing, ...fresh];
      _ref.read(currentPlaylistProvider.notifier).state = newList;
      _log('+${fresh.length} songs queued');
      if (!prefetch) {
        final idx  = _ref.read(currentSongIndexProvider) ?? 0;
        final next = idx + 1;
        if (next < newList.length) _doSkip(newList[next], next);
      }
    } else if (!prefetch) {
      final idx = _ref.read(currentSongIndexProvider) ?? 0;
      final pl  = _ref.read(currentPlaylistProvider);
      if (idx + 1 < pl.length) _doSkip(pl[idx + 1], idx + 1);
    }
  }

  Future<List<Song>> _getSimilarSongs(Song song) async {
    final artist      = song.artist.isNotEmpty ? song.artist : '';
    final lang        = song.language.toLowerCase() != 'unknown'
        ? song.language : '';
    final searchQuery = _ref.read(queueMetaProvider).searchQuery ?? '';

    final futures = <Future<List<Song>>>[_api.getRecommendations(song)];
    if (artist.isNotEmpty) {
      futures.add(_api.searchSongs('$artist songs', page: 1));
      futures.add(_api.getArtistSongs(artist));
    }
    if (lang.isNotEmpty) {
      futures.add(_api.searchSongs('best $lang songs', page: 1));
    }
    if (searchQuery.isNotEmpty &&
        searchQuery.toLowerCase() != song.title.toLowerCase()) {
      futures.add(_api.searchSongs(searchQuery, page: 2));
      futures.add(_api.searchSongs(searchQuery, page: 3));
    }

    final results = await Future.wait(futures);
    final seen = <String>{};
    return results
        .expand((l) => l)
        .where((s) => seen.add(s.id) && s.id != song.id)
        .toList()..shuffle();
  }

  // ─────────────────────────────────────────────────────────────
  // MISC
  // ─────────────────────────────────────────────────────────────

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?>   get durationStream    => _player.durationStream;
  Stream<Duration>    get positionStream    => _player.positionStream;

  Future<void> togglePlayPause() async =>
      _player.playing ? await _player.pause() : _player.play();

  // Sync version for use as VoidCallback in audio_handler
  void togglePlayPauseSync() =>
      _player.playing ? _player.pause() : _player.play();

  Future<void> seekTo(Duration position) async =>
      _player.seek(position);

  Future<void> stop() async => _player.stop();

  void setCrossfade({required bool enabled, required Duration duration}) {
    _crossfadeEnabled  = enabled;
    _crossfadeDuration = duration;
  }

  void setGapless(bool enabled) => _gaplessEnabled = enabled;
  Future<void> attachEqSession() async {}
  void dispose() => _player.dispose();
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────

final repeatModeProvider = StateProvider<RepeatMode>((ref) => RepeatMode.off);
final isShuffleProvider  = StateProvider<bool>((ref) => false);
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