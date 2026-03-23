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

  // App-specific Spotify Credentials
  final String _clientId = 'db4a233d158d4f1090ea4613cfe61c1e';
  final String _clientSecret = 'baddd033b6b745a4a8693d9d2ef10397';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  SpotifyImportService(this._api, this._db);

  // ── Obtain Access Token ──────────────────────────────────────────────────

  Future<String?> _getAccessToken() async {
    try {
      final credentials = base64.encode(utf8.encode('$_clientId:$_clientSecret'));
      final res = await _dio.post(
        'https://accounts.spotify.com/api/token',
        options: Options(
          headers: {
            'Authorization': 'Basic $credentials',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
        data: 'grant_type=client_credentials',
      );
      if (res.statusCode == 200) {
        return res.data['access_token'];
      }
    } catch (e) {
      print('[SPOTIFY_AUTH_ERROR] $e');
    }
    return null;
  }

  // ── Streaming Playlist Import ────────────────────────────────────────────

  Stream<ImportLogEntry> importPlaylist(String spotifyUrl) async* {
    yield ImportLogEntry(ImportLogType.info, 'Analysing Spotify URL...');

    final playlistId = _extractPlaylistId(spotifyUrl);
    if (playlistId == null) {
      yield ImportLogEntry(ImportLogType.error,
          'Invalid Spotify URL!\nFormat expected:\nhttps://open.spotify.com/playlist/...');
      return;
    }

    yield ImportLogEntry(ImportLogType.info, 'Connecting to Spotify servers...');
    
    final token = await _getAccessToken();
    if (token == null) {
      yield ImportLogEntry(ImportLogType.error, 'Failed to authenticate with Spotify.');
      return;
    }

    yield ImportLogEntry(ImportLogType.success, 'Connected securely.');
    yield ImportLogEntry(ImportLogType.info, 'Fetching playlist details...');

    String playlistName = 'Imported Playlist';
    List<_SpotifyTrack> tracks = [];

    try {
      final res = await _dio.get(
        'https://api.spotify.com/v1/playlists/$playlistId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      playlistName = res.data['name'] ?? 'Imported Playlist';
      yield ImportLogEntry(ImportLogType.success, 'Found playlist: "$playlistName"');

      yield ImportLogEntry(ImportLogType.info, 'Downloading massive tracklist...');
      
      var tracksData = res.data['tracks'];
      while (tracksData != null) {
        final items = tracksData['items'] as List;
        for (final item in items) {
          final trackNode = item['track'];
          if (trackNode == null) continue; // Skip local/invalid files
          
          final title = trackNode['name'] ?? '';
          final artistsList = trackNode['artists'] as List? ?? [];
          final artist = artistsList.map((a) => a['name']).join(', ');

          tracks.add(_SpotifyTrack(title: title, artist: artist));
        }

        final nextUrl = tracksData['next'];
        if (nextUrl != null) {
          final nextRes = await _dio.get(
            nextUrl,
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          tracksData = nextRes.data;
        } else {
          tracksData = null; // No more pages
        }
      }

    } on DioException catch (e) {
      yield ImportLogEntry(ImportLogType.error,
          'Spotify API request failed: ${e.message}');
      return;
    } catch (e) {
      yield ImportLogEntry(ImportLogType.error, 'Unexpected error: $e');
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