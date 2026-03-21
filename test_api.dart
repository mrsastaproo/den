import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(baseUrl: 'https://jiosaavn-api-angv.onrender.com/api'));
  
  print('Fetching songs...');
  try {
    final res = await dio.get('/search/songs', queryParameters: {'query': 'arijit singh', 'limit': 5});
    final results = res.data['data']?['results'] as List?;
    if (results == null) {
      print('No results found for search');
      return;
    }
    
    for (final s in results) {
      final id = s['id'];
      final title = s['name'] ?? s['title'];
      print('Testing $title (ID: $id)...');
      
      try {
        final sRes = await dio.get('/songs', queryParameters: {'ids': id});
        final sData = sRes.data['data'] as List?;
        if (sData == null || sData.isEmpty) {
          print('  -> FAIL: data is empty/null');
          continue;
        }
        final song = sData[0];
        final downloadUrls = song['downloadUrl'] as List?;
        if (downloadUrls == null || downloadUrls.isEmpty) {
          print('  -> FAIL: downloadUrls is empty');
          continue;
        }
        final best = downloadUrls.lastWhere(
          (u) => u['quality'] == '320kbps',
          orElse: () => downloadUrls.last);
        final url = best['url'];
        print('  -> SUCCESS URL: $url');
      } catch (e) {
        print('  -> ERROR fetching details: $e');
      }
    }
  } catch (e) {
    print('General error: $e');
  }
}
