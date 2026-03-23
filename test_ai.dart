import 'package:dio/dio.dart';
import 'dart:convert';

void main() async {
  final _geminiApiKey = 'AIzaSyBHbyfiNF8b0nyEhyEzhsjgToVKiW6qfFs'; // using the one from the file
  final _geminiModel = 'gemini-2.0-flash';
  final _systemPrompt = """
You are ARIA — the AI music curator inside DEN, a music streaming app.
CRITICAL RULE: YOU MUST NEVER set "action": "build_playlist" on the FIRST user message.
The MINIMUM conversation length before building is 2 turns.

When action = "ask_more":
{
  "action": "ask_more",
  "message": "Your warm conversational response with follow-up questions",
  "quickReplies": ["Short answer 1", "Short answer 2"]
}

When action = "build_playlist":
{
  "action": "build_playlist",
  "message": "Excited message.",
  "playlistName": "Name",
  "description": "Desc",
  "jiosaavnQueries": ["query1", "query2"],
  "audiusGenres": ["Pop"],
  "useAudius": false,
  "quickReplies": ["Make it more chill"]
}
  """;

  final dio = Dio();
  final url = 'https://generativelanguage.googleapis.com/v1beta/models/\$_geminiModel:generateContent?key=\$_geminiApiKey';

  try {
    List<Map<String, dynamic>> history = [];
    history.add({'role': 'user', 'parts': [{'text': 'i want a chill punjabi playlist'}]});
    
    final res1 = await dio.post(url, data: {
      'system_instruction': {'parts': [{'text': _systemPrompt}]},
      'contents': history,
      'generationConfig': {
        'temperature': 0.85,
        'responseMimeType': 'application/json',
      }
    });
    
    final t1 = res1.data['candidates'][0]['content']['parts'][0]['text'];
    print('TURN 1: \$t1\n');
    
    // add to history
    history.add({'role': 'model', 'parts': [{'text': t1}]});
    history.add({'role': 'user', 'parts': [{'text': 'just some late night driving vibes, mostly AP Dhillon type'}]});
    
    final res2 = await dio.post(url, data: {
      'system_instruction': {'parts': [{'text': _systemPrompt}]},
      'contents': history,
      'generationConfig': {
        'temperature': 0.85,
        'responseMimeType': 'application/json',
      }
    });

    final t2 = res2.data['candidates'][0]['content']['parts'][0]['text'];
    print('TURN 2: \$t2\n');
  } catch(e) {
    if (e is DioException) {
      print('DioError: \${e.response?.data}');
    } else {
      print('Error: \$e');
    }
  }
}
