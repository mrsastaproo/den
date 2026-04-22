import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    final search = await dio.get('https://jiosaavn-api-privatecvc2.vercel.app/search/songs', queryParameters: {'query': 'believer'});
    final data = search.data['data']['results'] as List;
    if (data.isNotEmpty) {
      final id = data[0]['id'];
      print('Found ID: \$id');
      
      final res1 = await dio.get('https://jiosaavn-api-privatecvc2.vercel.app/songs', queryParameters: {'ids': id});
      print('Songs by ids: \${res1.data.toString().substring(0, 100)}');
    }
  } catch(e) {
    if (e is DioException) {
      print('Error: \${e.response?.data}');
    } else {
      print(e);
    }
  }
}
