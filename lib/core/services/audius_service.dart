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

    return Song(
      id: 'audius_${track['id']}',
      title: track['title'] ?? '',
      artist: user?['name'] ?? '',
      album: '',
      image: artwork?['480x480'] ?? artwork?['150x150'] ?? '',
      url: '',
      duration: (track['duration'] ?? 0).toString(),
      year: '',
      language: 'english',
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