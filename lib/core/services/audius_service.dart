import 'package:dio/dio.dart';
import '../models/song.dart';

class AudiusService {
  // Audius is fully free + official
  static const String baseUrl = 'https://discoveryprovider.audius.co/v1';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  // Convert Audius track to Song model
  Song _trackToSong(Map<String, dynamic> track) {
    final artwork = track['artwork'] as Map<String, dynamic>?;
    final user = track['user'] as Map<String, dynamic>?;

    // Store the real Audius genre in the language field so PlayerService
    // can use it for genre-based autoplay after a search song finishes.
    final genre = (track['genre'] as String?)?.toLowerCase().trim() ?? 'all';

    return Song(
      id: 'audius_${track['id']}',
      title: track['title'] ?? '',
      artist: user?['name'] ?? '',
      album: '',
      image: artwork?['480x480'] ?? artwork?['150x150'] ?? '',
      url: '',
      duration: (track['duration'] ?? 0).toString(),
      year: '',
      language: genre, // genre stored here — used by smart queue
    );
  }

  // Get trending tracks
  Future<List<Song>> getTrending({int limit = 20}) async {
    try {
      final res = await _dio.get('/tracks/trending',
        queryParameters: {
          'limit': limit,
          'app_name': 'DEN',
        });
      final tracks = res.data['data'] as List? ?? [];
      return tracks.map((t) => _trackToSong(t)).toList();
    } catch (e) {
      print('Audius trending error: $e');
      return [];
    }
  }

  // Fetch tracks by genre — used for genre-based autoplay after a search song ends.
  // genre should be the raw Audius genre string e.g. 'electronic', 'hip-hop', 'pop'.
  Future<List<Song>> fetchByGenre(String genre, {int limit = 30, String? excludeId}) async {
    try {
      final res = await _dio.get('/tracks',
        queryParameters: {
          'genre': genre,
          'sort_by': 'plays',
          'order': 'desc',
          'limit': limit,
          'app_name': 'DEN',
        });
      final tracks = res.data['data'] as List? ?? [];
      return tracks
          .map((t) => _trackToSong(t))
          .where((s) => excludeId == null || s.id != excludeId)
          .toList();
    } catch (e) {
      print('Audius fetchByGenre error: $e');
      return [];
    }
  }

  // Search tracks
  Future<List<Song>> searchTracks(String query,
      {int limit = 20}) async {
    try {
      final res = await _dio.get('/tracks/search',
        queryParameters: {
          'query': query,
          'limit': limit,
          'app_name': 'DEN',
        });
      final tracks = res.data['data'] as List? ?? [];
      return tracks.map((t) => _trackToSong(t)).toList();
    } catch (e) {
      print('Audius search error: $e');
      return [];
    }
  }

  // Get stream URL for Audius track
  Future<String> getStreamUrl(String trackId) async {
    try {
      // Remove 'audius_' prefix
      final id = trackId.replaceFirst('audius_', '');
      return '$baseUrl/tracks/$id/stream?app_name=DEN';
    } catch (e) {
      return '';
    }
  }
}

