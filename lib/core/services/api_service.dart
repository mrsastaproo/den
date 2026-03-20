import 'package:dio/dio.dart';
import '../models/song.dart'; // ADD THIS LINE

class ApiService {
  static const String baseUrl = 'https://den-backend-pdo5.onrender.com';
  
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<List<Song>> searchSongs(String query, {int page = 1}) async {
    final res = await _dio.get('/search', queryParameters: {'q': query, 'page': page});
    return (res.data['results'] as List).map((e) => Song.fromJson(e)).toList();
  }

  Future<List<Song>> getTrending() async {
    final res = await _dio.get('/trending');
    return (res.data['results'] as List).map((e) => Song.fromJson(e)).toList();
  }

  Future<dynamic> getCharts() async {
    final res = await _dio.get('/charts');
    return res.data;
  }
}