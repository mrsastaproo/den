import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';

class YoutubeService {
  // Placeholder — USER: Provide your Render URL here!
  static const String proxyUrl = 'https://den-yt-proxy.onrender.com';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: proxyUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Future<List<Song>> search(String query) async {
    try {
      final res = await _dio.get('/search', queryParameters: {'q': query});
      final List results = res.data['data'] ?? [];
      
      return results.map((e) => Song(
        id: 'yt_${e['id']}',
        title: e['title'] ?? '',
        artist: e['artist'] ?? '',
        album: 'YouTube Music',
        image: e['image'] ?? '',
        url: '', // Resolved on play
        duration: e['duration']?.toString() ?? '0',
        year: DateTime.now().year.toString(),
        language: 'English',
        isExplicit: false,
      )).toList();
    } catch (e) {
      print('[YT] Search error: $e');
      return [];
    }
  }

  Future<String> getStreamUrl(String videoId) async {
    try {
      final id = videoId.replaceFirst('yt_', '');
      final res = await _dio.get('/stream', queryParameters: {'id': id});
      return res.data['url'] ?? '';
    } catch (e) {
      print('[YT] Stream error: $e');
      return '';
    }
  }
}

final youtubeServiceProvider = Provider<YoutubeService>((ref) => YoutubeService());
