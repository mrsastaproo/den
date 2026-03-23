import 'package:dio/dio.dart';
import 'dart:convert';

void main() async {
  final dio = Dio();
  try {
    final res = await dio.get(
      'https://open.spotify.com/embed/playlist/37i9dQZF1DXcBWIGoYBM5M?offset=50',
      options: Options(headers: {'User-Agent': 'Mozilla/5.0'})
    );
    final html = res.data.toString();
    
    final envMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>').firstMatch(html);
    if (envMatch != null) {
      final json = jsonDecode(envMatch.group(1)!);
      var items = json['props']['pageProps']['state']['data']['entity']['trackList'];
      print('Items length: ${items.length}');
      if (items.isNotEmpty) {
        print('First track: ${items[0]['title']} by ${items[0]['subtitle']}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
