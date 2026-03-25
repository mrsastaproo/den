import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';

class JamendoService {
  static const String baseUrl = 'https://api.jamendo.com/v3.0';
  static const String clientId = '709fa152';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Future<List<Song>> fetchByQuery(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await _dio.get('/tracks/', queryParameters: {
        'client_id': clientId,
        'format': 'json',
        'limit': limit,
        'search': query,
        'include': 'musicinfo',
      });

      final results = res.data['results'] as List? ?? [];
      return results.map((e) {
        // Build image URL safely from formats or raw
        String imageUrl = e['image'] ?? e['album_image'] ?? '';
        // If it's a small dimension format, prefer it if you want, but large is good
        
        return Song(
          id: 'jamendo_${e['id']}',
          title: e['name'] ?? 'Indie Track',
          artist: e['artist_name'] ?? 'Unknown Artist',
          album: e['album_name'] ?? 'Jamendo',
          image: imageUrl,
          url: e['audio'] ?? '', // Streaming URL
          duration: e['duration']?.toString() ?? '0',
          year: e['releasedate'] != null && e['releasedate'].toString().contains('-')
              ? e['releasedate'].toString().split('-').first
              : '',
          language: 'English',
          isExplicit: false,
          playCount: 0,
        );
      }).toList();
    } catch (e) {
      print('JamendoService Error [$query]: $e');
      return [];
    }
  }
}

final jamendoServiceProvider = Provider<JamendoService>((ref) {
  return JamendoService();
});
