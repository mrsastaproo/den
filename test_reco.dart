import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://jiosaavn-api-angv.onrender.com/api',
    connectTimeout: const Duration(seconds: 30),
  ));

  try {
    // 1. Search for Yalgaar to get ID
    print('Searching for Yalgaar...');
    final searchRes = await dio.get('/search/songs', queryParameters: {'query': 'Yalgaar', 'limit': 1});
    final results = searchRes.data['data']?['results'] as List? ?? [];
    if (results.isEmpty) {
      print('No song found for Yalgaar');
      return;
    }
    
    final song = results.first;
    final id = song['id'];
    print('Found Yalgaar ID: $id');

    // 2. Test /songs/{id}/suggestions
    print('\nTesting /songs/$id/suggestions...');
    try {
      final recoRes = await dio.get('/songs/$id/suggestions');
      print('Suggestions status: ${recoRes.statusCode}');
      final recoData = recoRes.data['data'] as List? ?? [];
      print('Suggestions Count: ${recoData.length}');
      if (recoData.isNotEmpty) {
        print('First recommendation: ${recoData.first['title']} by ${recoData.first['artist']}');
        return; // Success!
      }
    } catch (e) {
      print('Suggestions failed: $e');
    }

    // 3. Test /api/recommendations?id={id} or /recommendations
    print('\nTesting /songs/$id/recommendations...');
    try {
      final recoRes = await dio.get('/songs/$id/recommendations');
      print('Recommendations status: ${recoRes.statusCode}');
      final recoData = recoRes.data['data'] as List? ?? [];
      print('Recommendations Count: ${recoData.length}');
      if (recoData.isNotEmpty) {
        print('First recommendation: ${recoData.first['title']}');
      }
    } catch (e) {
      print('Recommendations failed: $e');
    }

  } catch (e) {
    print('Main error: $e');
  }
}
