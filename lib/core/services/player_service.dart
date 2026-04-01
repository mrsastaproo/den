import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../providers/music_providers.dart';
import '../providers/queue_meta.dart';
import 'database_service.dart';
import 'audius_service.dart';
import 'download_service.dart';
import 'settings_service.dart';
import 'social_service.dart';
import 'audio_handler.dart';
import 'youtube_service.dart';

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
  final AudioPlayer   _player;
  late ConcatenatingAudioSource _playlistSource;
  final ApiService    _api;
  final Ref           _ref;
  final AudiusService _audius = AudiusService();

  bool _skipInProgress  = false;
  int  _consecutiveErrors = 0;
  DateTime? _lastPrefetchAt;
  DateTime? _lastSaveTime; // Throttling for saving position

  bool     _crossfadeEnabled  = false;
  Duration _crossfadeDuration = const Duration(seconds: 3);
  // ignore: unused_field
  bool     _gaplessEnabled    = true;

  static AudioPlayer _resolvePlayer() {
    try {
      // ignore: unnecessary_cast
      final handler = audioHandler as dynamic; 
      if (handler is DenAudioHandler) {
        return handler.player;
      }
    } catch (_) {}
    return AudioPlayer(); // Fallback to safe local instance
  }

  PlayerService(this._api, this._ref) : _player = _resolvePlayer() {
    _playlistSource = ConcatenatingAudioSource(children: []);
    _initListeners();
    _initOverlayListener();
    _loadSavedSettings();
    
    // Register lock screen / notification button callbacks
    try {
      (audioHandler as DenAudioHandler).setCallbacks(
        onSkipNext: skipNext,
        onSkipPrev: skipPrev,
        onToggle:   togglePlayPauseSync,
      );
    } catch (_) {}

    // Restore state from disk on launch
    Future.microtask(() => restorePlaybackState());
  }

  Future<void> _loadSavedSettings() async {
    // Load persisted playback settings so they apply from first track
    _crossfadeEnabled  = _ref.read(crossfadeEnabledProvider);
    _crossfadeDuration = Duration(
        seconds: _ref.read(crossfadeDurationProvider).toInt());
    _gaplessEnabled    = _ref.read(gaplessPlaybackProvider);
  }

  // ─────────────────────────────────────────────────────────────
  // LISTENERS
  // ─────────────────────────────────────────────────────────────

  void _initListeners() {
    _player.playerStateStream.listen((state) {
      _ref.read(isPlayingProvider.notifier).state = state.playing;
      updateOverlay();
      if (state.processingState == ProcessingState.completed) {

        // Never auto-advance during a manual skip
        if (_skipInProgress) return;

        _log('Track completed → auto advance');
        _autoAdvance();
      }
    });

    // Detect transitions for gapless prefetch and UI sync
    _player.currentIndexStream.listen((index) {
      if (index == null || _skipInProgress) return;
      
      final currentPlaylist = _ref.read(currentPlaylistProvider);
      final currentUIIndex = _ref.read(currentSongIndexProvider);
      
      if (index > 0) {
        final globalIndex = currentUIIndex + index;
        if (globalIndex < currentPlaylist.length) {
          _log('Gapless transition to global index $globalIndex');
          final song = currentPlaylist[globalIndex];
          _ref.read(currentSongIndexProvider.notifier).state = globalIndex;
          _ref.read(currentSongProvider.notifier).state = song;
          
          _prefetchNextTrack(globalIndex);
          _syncMetadata(song);
        }
      }
    });

    // Background prefetch — max once per 10s
    _player.positionStream.listen((pos) {
      if (pos.inSeconds < 5) return;
      if (_skipInProgress) return;

      final playlist  = _ref.read(currentPlaylistProvider);
      final idx       = _ref.read(currentSongIndexProvider);
      final remaining = playlist.length - idx - 1;

      if (remaining <= 2) {
        // ENFORCE AUTOPLAY SETTING
        final autoplay = _ref.read(autoplayEnabledProvider);
        if (!autoplay) return;

        final now = DateTime.now();
        if (_lastPrefetchAt != null &&
            now.difference(_lastPrefetchAt!).inSeconds < 10) return;
        _lastPrefetchAt = now;
        _fetchSmartQueue(prefetch: true);
      }

      // ── SAVE STATE PERIODICALLY (approx every 10s) ──
      final now = DateTime.now();
      if (_lastSaveTime == null || now.difference(_lastSaveTime!).inSeconds >= 10) {
        _lastSaveTime = now;
        _savePlaybackState();
      }

      updateOverlay();
    });
  }

  void _initOverlayListener() {
    if (kIsWeb || !Platform.isAndroid) return;
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == 'toggle') togglePlayPauseSync();
      if (event == 'skipNext') skipNext();
      if (event == 'skipPrev') skipPrev();
    });
  }

  void updateOverlay() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final song = _ref.read(currentSongProvider);
    if (song == null) return;
    final isPlaying = _ref.read(isPlayingProvider);
    final pos = _player.position;
    final dur = _player.duration ?? Duration.zero;
    final progress = dur.inMilliseconds > 0 
        ? pos.inMilliseconds / dur.inMilliseconds 
        : 0.0;

    if (await FlutterOverlayWindow.isActive()) {
      FlutterOverlayWindow.shareData({
        'title': song.title,
        'artist': song.artist,
        'image': song.image,
        'isPlaying': isPlaying,
        'progress': progress,
      });
    }
  }


  // ─────────────────────────────────────────────────────────────
  // AUTO ADVANCE
  // ─────────────────────────────────────────────────────────────

  void _autoAdvance() {
    // ── Sleep Timer: End of track ──
    final sleepTimer = _ref.read(sleepTimerProvider);
    if (sleepTimer == 'end_of_track') {
      _log('Sleep Timer: End of track reached → pausing');
      _player.pause();
      // Clear the timer setting
      _ref.read(sleepTimerProvider.notifier).set(null);
      return;
    }

    if (_ref.read(repeatModeProvider) == RepeatMode.one) {

      _player.seek(Duration.zero).then((_) => _player.play());
      return;
    }
    final playlist = _ref.read(currentPlaylistProvider);
    final idx      = _ref.read(currentSongIndexProvider);
    if (idx + 1 < playlist.length) {
      _doSkip(playlist[idx + 1], idx + 1);
    } else {
      // End of playlist — only fetch smart queue if Autoplay is ON
      final autoplay = _ref.read(autoplayEnabledProvider);
      if (autoplay) {
        _fetchSmartQueue();
      } else {
        _log('Autoplay OFF — stopping at end of playlist');
        _player.stop();
      }
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
    final prevIndex = _ref.read(currentSongIndexProvider);
    _ref.read(currentSongIndexProvider.notifier).state = index;
    _ref.read(currentSongProvider.notifier).state      = song;
    updateOverlay();


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
    Duration? startAt,
    bool autoPlay = true,
  }) async {
    _log('Loading: ${song.title}');
    try {
      // await _player.stop(); // Removed for gapless

      final dl = _ref.read(downloadServiceProvider);
      AudioSource source;

      if (await dl.isDownloaded(song.id)) {
        final path = await dl.getDownloadPath(song.id);
        _log('Offline: $path');
        source = AudioSource.uri(Uri.file(path));
      } else {
        // ── Stream URL ────────────────────────────────────────
        if (_ref.read(offlineModeProvider)) {
          _log('Offline mode — skipping ${song.title}');
          _handleError(song, index, prevSong: prevSong, prevIndex: prevIndex);
          return;
        }

        _log('Fetching URL for ${song.title}…');
        
        // Respect streaming quality setting
        String url = song.url;
        if (url.isEmpty) {
          final quality = _ref.read(streamingQualityProvider);
          
          if (song.id.startsWith('audius_')) {
            url = await _audius.getStreamUrl(song.id);
          } else if (song.id.startsWith('jamendo_')) {
             url = await _api.getStreamUrl(song.id, quality: quality);
          } else if (song.id.startsWith('yt_')) {
             url = await _ref.read(youtubeServiceProvider).getStreamUrl(song.id);
          } else {
            // Saavn track — check if we should apply the "Best Legal Match" engine
            // for English songs to avoid the 30s preview trap.
            final isEnglish = song.language.toLowerCase() == 'english';
            if (isEnglish) {
               _log('English track detected — enforcing legal matching engine');
               final bestMatch = await _api.findBestLegalMatch(song.title, song.artist);
               
               // If we found a match, check if it's full length (> 60s)
               final matchDur = bestMatch != null ? (int.tryParse(bestMatch.duration) ?? 0) : 0;
               
               if (matchDur > 60) {
                 _log('Found superior full-length match: ${bestMatch!.id}');
                 url = await _api.getStreamUrl(bestMatch.id, quality: quality);
               } else {
                 // Final fallback: YouTube (guaranteed full song)
                 _log('No legal full version found. Using YouTube fallback…');
                 final ytResults = await _ref.read(youtubeServiceProvider).search('${song.title} ${song.artist}');
                 if (ytResults.isNotEmpty) {
                    final yt = ytResults.first;
                    url = await _ref.read(youtubeServiceProvider).getStreamUrl(yt.id);
                    _log('Resolved via YouTube Proxy: ${yt.id}');
                 } else {
                    // Last ditch: just play the Saavn version (even if preview)
                    url = await _api.getStreamUrl(song.id, quality: quality);
                 }
               }
            } else {
              url = await _api.getStreamUrl(song.id, quality: quality);
            }
          }
        }

        if (url.isEmpty) {
          _log('No URL — skipping ${song.title}');
          _handleError(song, index, prevSong: prevSong, prevIndex: prevIndex);
          return;
        }

        _log('URL ok, setting source…');
        source = AudioSource.uri(Uri.parse(url));
      }

      // ── CONCATENATION MGMT ────────────────────────────────
      _playlistSource = ConcatenatingAudioSource(children: [source]);
      await _player.setAudioSource(_playlistSource);

      if (startAt != null) {
        await _player.seek(startAt);
      }

      // ── Success ───────────────────────────────────────────
      _consecutiveErrors = 0;

      if (autoPlay) {
        _player.play(); // DO NOT AWAIT — just_audio's play() completes when track finishes
      }
      _log('▶ loaded ${song.title} @ ${startAt?.inSeconds ?? 0}s');

      // ── Crossfade: fade in new track ─────────────────────
      final normalise = _ref.read(normalizationEnabledProvider);
      
      if (_crossfadeEnabled && _crossfadeDuration.inMilliseconds > 0) {
        final targetVol = normalise ? 0.88 : 1.0;
        final steps = 20;
        final stepDur = _crossfadeDuration ~/ steps;
        // Fire and forget so we don't keep _skipInProgress=true
        Future.microtask(() async {
          for (int i = 1; i <= steps; i++) {
            try { await _player.setVolume((i / steps) * targetVol); } catch (_) {}
            await Future.delayed(stepDur);
          }
          try { await _player.setVolume(targetVol); } catch (_) {}
        });
      } else {
        await _player.setVolume(normalise ? 0.88 : 1.0);
      }

      // ── Attach EQ to new audio session ───────────────────
      // Each track gets its own Android AudioSession ID.
      // We must re-attach the EQ after every successful load.
      Future.microtask(() async {
        try {
          final sid = _player.androidAudioSessionId;
          await _ref.read(eqProvider.notifier).attachSession(sid);
        } catch (_) {}
      });

      _syncMetadata(song);

      // ── Prefetch NEXT track URL for gapless feel ────────────────
      _prefetchNextTrack(index);

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
    final idx      = _ref.read(currentSongIndexProvider);
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
    final idx      = _ref.read(currentSongIndexProvider);
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
  // SETTINGS INTEGRATION
  // ─────────────────────────────────────────────────────────────

  /// Called by settings_screen when crossfade toggle/slider changes.
  void setCrossfade({required bool enabled, required Duration duration}) {
    _crossfadeEnabled  = enabled;
    _crossfadeDuration = duration;
  }

  /// Called by settings_screen when gapless toggle changes.
  /// just_audio handles gapless natively when using ConcatenatingAudioSource.
  /// We store the flag so _loadAndPlay can respect it in the future.
  void setGapless(bool enabled) {
    _gaplessEnabled = enabled;
  }

  /// Re-apply volume to reflect the current normalization setting.
  /// Called when the normalization toggle changes while a song is playing.
  void reapplyNormalization() {
    final normalise = _ref.read(normalizationEnabledProvider);
    _player.setVolume(normalise ? 0.88 : 1.0).catchError((_) => {});
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

    // Only fallback to trending if we are truly desperate AND the language matches.
    // This prevents English pop from suggesting Hindi trending religious tracks.
    if (recs.isEmpty) {
      try { 
        final trending = await _api.getTrending(); 
        recs = trending.where((s) => s.language.toLowerCase() == current.language.toLowerCase()).toList();
      } catch (_) {}
    }

    final existing    = _ref.read(currentPlaylistProvider);
    final existingIds = existing.map((s) => s.id).toSet();
    final fresh = recs.where((s) => !existingIds.contains(s.id)).toList();

    if (fresh.isNotEmpty) {
      final newList = [...existing, ...fresh];
      _ref.read(currentPlaylistProvider.notifier).state = newList;
      _log('+${fresh.length} songs queued');
      if (!prefetch) {
        final idx  = _ref.read(currentSongIndexProvider);
        final next = idx + 1;
        if (next < newList.length) _doSkip(newList[next], next);
      } else {
        final idx = _ref.read(currentSongIndexProvider);
        _prefetchNextTrack(idx);
      }
    } else if (!prefetch) {
      final idx = _ref.read(currentSongIndexProvider);
      final pl  = _ref.read(currentPlaylistProvider);
      if (idx + 1 < pl.length) _doSkip(pl[idx + 1], idx + 1);
    }
  }

  Future<List<Song>> _getSimilarSongs(Song song) async {
    final artist      = song.artist.isNotEmpty ? song.artist : '';
    final searchQuery = _ref.read(queueMetaProvider).searchQuery ?? '';

    final futures = <Future<List<Song>>>[
      _api.getRecommendations(song).catchError((_) => <Song>[])
    ];
    
    if (artist.isNotEmpty) {
      // ── Specific Artist Radio ──────────────────────────────
      futures.add(_api.searchSongs('$artist radio', page: 1).catchError((_) => <Song>[]));
      futures.add(_api.getArtistSongs(artist).catchError((_) => <Song>[]));
    }
    
    if (searchQuery.isNotEmpty &&
        searchQuery.toLowerCase() != song.title.toLowerCase()) {
      // ── Contextual Search Fallback ─────────────────────────
      futures.add(_api.searchSongs(searchQuery, page: 2).catchError((_) => <Song>[]));
    }

    final results = await Future.wait(futures);
    final seen = <String>{};
    return results
        .expand((l) => l)
        .where((s) => seen.add(s.id) && s.id != song.id)
        .toList()..shuffle();
  }

  Future<void> _prefetchNextTrack(int currentIndex) async {
    final playlist = _ref.read(currentPlaylistProvider);
    final nextIndex = currentIndex + 1;
    if (nextIndex >= playlist.length) return;

    final nextSong = playlist[nextIndex];

    final dl = _ref.read(downloadServiceProvider);
    if (await dl.isDownloaded(nextSong.id)) return;

    final quality = _ref.read(streamingQualityProvider);
    _log('Prefetching next track: ${nextSong.title}');
    
    try {
      final url = nextSong.id.startsWith('audius_')
          ? await _audius.getStreamUrl(nextSong.id)
          : await _api.getStreamUrl(nextSong.id, quality: quality);
      if (url.isNotEmpty) {
        final source = AudioSource.uri(Uri.parse(url));
        if (_playlistSource.length <= 1) {
          await _playlistSource.add(source);
          _log('Next track added to concatenation source.');
        }
      }
    } catch (e) {
      _log('Prefetch error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MISC
  // ─────────────────────────────────────────────────────────────

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?>   get durationStream    => _player.durationStream;
  Stream<Duration>    get positionStream    => _player.positionStream;

  Future<void> togglePlayPause() async {
    _player.playing ? await _player.pause() : await _player.play();
    _savePlaybackState();
  }

  // Sync version for use as VoidCallback in audio_handler
  void togglePlayPauseSync() {
    _player.playing ? _player.pause() : _player.play();
    _savePlaybackState();
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
    _savePlaybackState();
  }

  void _syncMetadata(Song song) {
    try {
      (audioHandler as DenAudioHandler).updateNowPlaying(song);
    } catch (_) {}

    final isPrivate = _ref.read(privateSessionProvider);
    if (!isPrivate) {
      _ref.read(databaseServiceProvider).addToHistory(song);
      _ref.read(socialServiceProvider).updatePresence(true, nowPlaying: {
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'image': song.image,
      });
    }
    updateOverlay();
    _savePlaybackState(); // Save state on song change
  }

  // ─────────────────────────────────────────────────────────────
  // PERSISTENCE
  // ─────────────────────────────────────────────────────────────

  Future<void> _savePlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final song = _ref.read(currentSongProvider);
      final playlist = _ref.read(currentPlaylistProvider);
      final index = _ref.read(currentSongIndexProvider);
      final pos = _player.position.inMilliseconds;
      final isPlaying = _player.playing;

      if (song != null) {
        await prefs.setString('last_song', jsonEncode(song.toJson()));
      }
      if (playlist.isNotEmpty) {
        final list = playlist.map((s) => s.toJson()).toList();
        await prefs.setString('last_playlist', jsonEncode(list));
      }
      await prefs.setInt('last_index', index);
      await prefs.setInt('last_position', pos);
      await prefs.setBool('last_is_playing', isPlaying);
      // _log('💾 Saved state: ${song?.title} at $pos ms');
    } catch (e) {
      _log('Error saving state: $e');
    }
  }

  Future<void> restorePlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songJson = prefs.getString('last_song');
      final playlistJson = prefs.getString('last_playlist');
      final index = prefs.getInt('last_index') ?? 0;
      final posMs = prefs.getInt('last_position') ?? 0;
      final isPlaying = prefs.getBool('last_is_playing') ?? false;

      if (playlistJson != null) {
        final List<dynamic> list = jsonDecode(playlistJson);
        final playlist = list.map((item) => Song.fromJson(item)).toList();
        _ref.read(currentPlaylistProvider.notifier).state = playlist;
      }

      if (songJson != null) {
        final song = Song.fromJson(jsonDecode(songJson));
        _ref.read(currentSongProvider.notifier).state = song;
        _ref.read(currentSongIndexProvider.notifier).state = index;

        _log('Restoring state: ${song.title} at $posMs ms');
        
        await _loadAndPlay(
          song,
          index,
          startAt: Duration(milliseconds: posMs),
          autoPlay: isPlaying,
        );
      }
    } catch (e) {
      _log('Error restoring state: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _ref.read(socialServiceProvider).updatePresence(true, nowPlaying: null);
    _savePlaybackState(); // Save on stop
  }

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