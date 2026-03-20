import 'package:dio/dio.dart';
import '../models/song.dart';

class ApiService {
  static const String baseUrl = 'https://jiosaavn-api-angv.onrender.com/api';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  // Search songs
  Future<List<Song>> searchSongs(String query, {int page = 1}) async {
    try {
      final res = await _dio.get('/search/songs',
          queryParameters: {'query': query, 'page': page, 'limit': 20});
      final results = res.data['data']['results'] as List;
      return results.map((e) => Song.fromSumitApi(e)).toList();
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }

  // Trending — searches popular hindi songs
  Future<List<Song>> getTrending() async {
    try {
      final res = await _dio.get('/search/songs',
          queryParameters: {'query': 'top hindi hits 2024', 'limit': 30});
      final results = res.data['data']['results'] as List;
      return results.map((e) => Song.fromSumitApi(e)).toList();
    } catch (e) {
      print('Trending error: $e');
      return [];
    }
  }

  // Get stream URL by song ID
  Future<String> getStreamUrl(String songId) async {
    try {
      final res = await _dio.get('/songs', queryParameters: {'ids': songId});
      final data = res.data['data'] as List?;
      if (data == null || data.isEmpty) return '';

      final song = data[0];
      final downloadUrls = song['downloadUrl'] as List?;
      if (downloadUrls == null || downloadUrls.isEmpty) return '';

      // Get 320kbps, fallback to highest available
      final best = downloadUrls.lastWhere(
        (u) => u['quality'] == '320kbps',
        orElse: () => downloadUrls.last,
      );
      return best['url'] ?? '';
    } catch (e) {
      print('Stream URL error: $e');
      return '';
    }
  }
}