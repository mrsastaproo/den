import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';

class SoundcloudService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    },
  ));

  String? _clientId;
  final Map<String, List<Song>> _searchCache = {};

  // Get a fresh client_id from SoundCloud's main page or assets
  Future<String?> _getClientId() async {
    if (_clientId != null) return _clientId;
    try {
      final res = await _dio.get('https://soundcloud.com');
      final content = res.data.toString();
      
      // Look for script tags that might contain the client_id
      final scriptRegex = RegExp(r'src="([^"]+?\.js)"');
      final scripts = scriptRegex.allMatches(content).map((m) => m.group(1)).toList();
      
      for (final scriptUrl in scripts.reversed.take(5)) {
        try {
          final sRes = await _dio.get(scriptUrl!);
          final sContent = sRes.data.toString();
          final idMatch = RegExp(r'client_id:"([^"]+?)"').firstMatch(sContent) ??
                          RegExp(r'client_id=([a-zA-Z0-9]{32})').firstMatch(sContent);
          if (idMatch != null) {
            _clientId = idMatch.group(1);
            return _clientId;
          }
        } catch (_) {}
      }
    } catch (e) {
      print('[SC] ClientID error: $e');
    }
    // Fallback to a common public ID if scraping fails
    return '8P6C0v9YV1r8p4o1V9b8W7x6Z5y4X3w2'; 
  }

  Future<List<Song>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    
    final cacheKey = '$query|$limit';
    if (_searchCache.containsKey(cacheKey)) return _searchCache[cacheKey]!;

    try {
      final cid = await _getClientId();
      final res = await _dio.get(
        'https://api-v2.soundcloud.com/search/tracks',
        queryParameters: {
          'q': query,
          'client_id': cid,
          'limit': limit,
          'offset': 0,
        },
      );
      
      final List results = res.data['collection'] ?? [];
      final songs = results.map((e) {
        return Song(
          id: 'sc_${e['id']}',
          title: e['title'] ?? '',
          artist: e['user']?['username'] ?? 'Unknown Artist',
          album: 'SoundCloud',
          image: (e['artwork_url'] ?? e['user']?['avatar_url'] ?? '').toString().replaceAll('large', 't500x500'),
          url: '', // Resolved on play
          duration: ((e['duration'] ?? 0) / 1000).round().toString(),
          year: DateTime.now().year.toString(),
          language: 'Unknown',
          isExplicit: false,
          playCount: e['playback_count'] ?? 0,
        );
      }).toList();

      _searchCache[cacheKey] = songs;
      return songs;
    } catch (e) {
      print('[SC] Search error: $e');
      return [];
    }
  }

  Future<List<Song>> searchByMeta(String title, String artist) async {
    return search('$title $artist', limit: 5);
  }

  Future<String> getStreamUrl(String trackId) async {
    try {
      final cleanId = trackId.startsWith('sc_') ? trackId.substring(3) : trackId;
      final cid = await _getClientId();
      
      // Get track info to find the streaming URL
      final res = await _dio.get(
        'https://api-v2.soundcloud.com/tracks/$cleanId',
        queryParameters: {'client_id': cid},
      );
      
      final media = res.data['media']?['transcodings'] as List?;
      if (media == null || media.isEmpty) return '';
      
      // Prefer progressive mp3 if available, otherwise hls
      final progressive = media.firstWhere(
        (t) => t['format']?['protocol'] == 'progressive',
        orElse: () => media.first,
      );
      
      final urlRes = await _dio.get(
        progressive['url'],
        queryParameters: {'client_id': cid},
      );
      
      return urlRes.data['url'] ?? '';
    } catch (e) {
      print('[SC] Stream error: $e');
      return '';
    }
  }
}

final soundcloudServiceProvider = Provider<SoundcloudService>((ref) => SoundcloudService());
