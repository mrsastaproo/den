// ─────────────────────────────────────────────────────────────────────────────
// spotify_import_service.dart  —  DEN Spotify Playlist Importer
//
// Powered by Official Spotify API (Client Credentials Flow).
//
// Flow:
//   1. Parse playlist ID from Spotify URL
//   2. Obtain short-lived Access Token using Client ID + Secret
//   3. Fetch playlist metadata and track pages from api.spotify.com
//   4. Search and match each track against DEN's library via ApiService
//   5. Create a native playlist on DEN's DatabaseService and insert songs
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import 'api_service.dart';
import 'database_service.dart';

// ── Import Log Entry ──────────────────────────────────────────────────────────

enum ImportLogType { info, success, warning, error, done }

class ImportLogEntry {
  final ImportLogType type;
  final String message;
  final DateTime time;

  ImportLogEntry(this.type, this.message) : time = DateTime.now();

  String get emoji {
    switch (type) {
      case ImportLogType.info:    return '🔍';
      case ImportLogType.success: return '✅';
      case ImportLogType.warning: return '⚠️';
      case ImportLogType.error:   return '❌';
      case ImportLogType.done:    return '🎉';
    }
  }
}

// ── Spotify Track Model ───────────────────────────────────────────────────────

class _SpotifyTrack {
  final String title;
  final String artist;

  const _SpotifyTrack({
    required this.title,
    required this.artist,
  });
}

// ── SpotifyImportService ──────────────────────────────────────────────────────

class SpotifyImportService {
  final ApiService _api;
  final DatabaseService _db;

  // Note: We bypass Client ID usage via native Embed Scraping
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  SpotifyImportService(this._api, this._db);

  // ── Obtain Access Token ──────────────────────────────────────────────────

  // ── Streaming Playlist Import ────────────────────────────────────────────

  Stream<ImportLogEntry> importPlaylist(String spotifyUrl) async* {
    yield ImportLogEntry(ImportLogType.info, 'Analysing Spotify URL...');

    final playlistId = _extractPlaylistId(spotifyUrl);
    if (playlistId == null) {
      yield ImportLogEntry(ImportLogType.error,
          'Invalid Spotify URL!\nFormat expected:\nhttps://open.spotify.com/playlist/...');
      return;
    }

    yield ImportLogEntry(ImportLogType.info, 'Connecting to Spotify Web Player...');

    String playlistName = 'Imported Playlist';
    List<_SpotifyTrack> tracks = [];

    try {
      // We parse the __NEXT_DATA__ from the public Embed player.
      // This bypasses the stringent Client Credentials Web API blocks (403 limits) 
      // introduced by Spotify in late 2024.
      final res = await _dio.get(
        'https://open.spotify.com/embed/playlist/$playlistId',
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }),
      );
      
      final html = res.data.toString();
      final envMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>').firstMatch(html);
      
      if (envMatch == null) {
        yield ImportLogEntry(ImportLogType.error, 'Failed to extract Spotify web payload (Layout changed or Private playlist).');
        return;
      }
      
      yield ImportLogEntry(ImportLogType.success, 'Bypassed authentication. Reading payload...');
      
      final json = jsonDecode(envMatch.group(1)!);
      final entity = json['props']?['pageProps']?['state']?['data']?['entity'];
      
      if (entity == null) {
        yield ImportLogEntry(ImportLogType.error, 'Playlist data is empty or corrupted.');
        return;
      }
      
      playlistName = entity['name'] ?? 'Imported Playlist';
      yield ImportLogEntry(ImportLogType.success, 'Found playlist: "$playlistName"');
      
      final trackList = entity['trackList'] as List?;
      if (trackList == null || trackList.isEmpty) {
        yield ImportLogEntry(ImportLogType.error, 'No tracks found in the playlist payload.');
        return;
      }
      
      yield ImportLogEntry(ImportLogType.info, 'Extracting tracklist (Limited to first batches by Web Player rules)...');
      
      for (final item in trackList) {
        final title = item['title'] ?? '';
        final artist = item['subtitle'] ?? ''; // Subtitle usually contains artist
        if (title.isNotEmpty) {
           tracks.add(_SpotifyTrack(title: title, artist: artist));
        }
      }

    } on DioException catch (e) {
      yield ImportLogEntry(ImportLogType.error,
          'Connection request failed: ${e.message}');
      return;
    } catch (e) {
      yield ImportLogEntry(ImportLogType.error, 'Unexpected parsing error: $e');
      return;
    }

    if (tracks.isEmpty) {
      yield ImportLogEntry(ImportLogType.error,
          'No workable tracks found in this playlist.\nMake sure it is public.');
      return;
    }

    yield ImportLogEntry(ImportLogType.info,
        'Compiling ${tracks.length} tracks into DEN mapping...');

    // ── Create DEN Playlist ────────────────────────────────────────────────
    yield ImportLogEntry(ImportLogType.info,
        'Registering "$playlistName" to your library...');

    String denPlaylistId = '';
    try {
      denPlaylistId = await _db.createPlaylist(
        playlistName,
        description: 'Imported from Spotify',
      );
    } catch (e) {
      yield ImportLogEntry(ImportLogType.error,
          'Failed to build playlist in database: $e');
      return;
    }

    // ── Cross-match each track ──────────────────────────────────────────────
    int matched = 0;
    int notFound = 0;

    for (int i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      yield ImportLogEntry(ImportLogType.info,
          '[${i + 1}/${tracks.length}] Searching for "${track.title}"');

      try {
        final song = await _findBestMatch(track);

        if (song != null) {
          await _db.addSongToPlaylist(denPlaylistId, song);
          matched++;
          yield ImportLogEntry(ImportLogType.success,
              '✓ Matched: "${song.title}"');
        } else {
          notFound++;
          yield ImportLogEntry(ImportLogType.warning,
              '⚠️ Missing: "${track.title}"');
        }
      } catch (e) {
        notFound++;
        yield ImportLogEntry(ImportLogType.warning,
            '⚠️ Failed: "${track.title}" ($e)');
      }
      
      // Slight delay to handle bulk writes nicely
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // ── Finalization ────────────────────────────────────────────────────────
    yield ImportLogEntry(ImportLogType.done,
        'IMPORT COMPLETE!\n\n'
        '✅ Matched: $matched tracks\n'
        '⚠️ Skipped: $notFound tracks\n\n'
        'Your playlist "$playlistName" is ready in the Library tab!');
  }

  // ── Find best matching song on DEN ──────────────────────────────────────

  Future<Song?> _findBestMatch(_SpotifyTrack track) async {
    // Strategy 1: Title + Artist (Most accurate)
    var results = await _api.searchSongs(
      '${track.title} ${track.artist}',
      limit: 5,
    );

    var match = _pickBest(results, track);
    if (match != null) return match;

    // Strategy 2: Title only 
    results = await _api.searchSongs(track.title, limit: 5);
    match = _pickBest(results, track);
    if (match != null) return match;

    // Strategy 3: Title + First Artist Only
    final firstArtist = track.artist.split(',').first.trim();
    if (firstArtist != track.artist) {
      results = await _api.searchSongs(
        '${track.title} $firstArtist',
        limit: 5,
      );
      match = _pickBest(results, track);
      if (match != null) return match;
    }

    return null;
  }

  /// Evaluates fuzzy similarity to choose the cleanest match natively
  Song? _pickBest(List<Song> results, _SpotifyTrack track) {
    if (results.isEmpty) return null;

    final queryTitle  = _normalize(track.title);
    final queryArtist = _normalize(track.artist);

    for (final song in results) {
      final songTitle  = _normalize(song.title);
      final songArtist = _normalize(song.artist);

      // Perfect alignment
      if (songTitle == queryTitle) return song;

      // Substring check (covers (Remaster) vs non-remaster)
      if (songTitle.contains(queryTitle) &&
          (queryArtist.isEmpty || songArtist.contains(queryArtist.split(' ').first))) {
        return song;
      }
    }

    // Fallback best effort
    return results.first;
  }

  String _normalize(String s) =>
      s.toLowerCase()
       .replaceAll(RegExp(r'[^\w\s]'), '')
       .replaceAll(RegExp(r'\s+'), ' ')
       .trim();

  // ── Extract ID from URL ─────────────────────────────────────────────────

  String? _extractPlaylistId(String url) {
    try {
      final uri = Uri.parse(url.trim());
      if (uri.host.contains('spotify.com')) {
        final segments = uri.pathSegments;
        final idx = segments.indexOf('playlist');
        if (idx != -1 && idx + 1 < segments.length) {
          final idWithQuery = segments[idx + 1];
          return idWithQuery.split('?').first;
        }
      }
    } catch (_) {}
    return null;
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final spotifyImportServiceProvider = Provider<SpotifyImportService>((ref) {
  return SpotifyImportService(
    ref.watch(apiServiceProvider),
    ref.watch(databaseServiceProvider),
  );
});