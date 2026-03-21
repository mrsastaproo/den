import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import 'api_service.dart';
import 'audius_service.dart';
import 'database_service.dart';

// ─── Result model returned to the UI ──────────────────────────────────────────

class GeneratedPlaylist {
  final String name;
  final String description;
  final List<Song> songs;

  const GeneratedPlaylist({
    required this.name,
    required this.description,
    required this.songs,
  });
}

// ─── State for the UI ─────────────────────────────────────────────────────────

enum GeneratorStatus { idle, thinking, searching, done, error }

class GeneratorState {
  final GeneratorStatus status;
  final String statusMessage;
  final GeneratedPlaylist? result;
  final String? error;
  final List<ChatMessage> messages;

  const GeneratorState({
    this.status = GeneratorStatus.idle,
    this.statusMessage = '',
    this.result,
    this.error,
    this.messages = const [],
  });

  GeneratorState copyWith({
    GeneratorStatus? status,
    String? statusMessage,
    GeneratedPlaylist? result,
    String? error,
    List<ChatMessage>? messages,
  }) =>
      GeneratorState(
        status: status ?? this.status,
        statusMessage: statusMessage ?? this.statusMessage,
        result: result ?? this.result,
        error: error ?? this.error,
        messages: messages ?? this.messages,
      );
}

class ChatMessage {
  final String text;
  final bool isUser;
  final GeneratedPlaylist? playlist; // non-null for AI messages that have a playlist

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.playlist,
  });
}

// ─── Service ──────────────────────────────────────────────────────────────────

class PlaylistGeneratorService extends StateNotifier<GeneratorState> {
  final ApiService _api;
  final AudiusService _audius;
  final DatabaseService _db;

  static const String _geminiApiKey = 'AIzaSyBHbyfiNF8b0nyEhyEzhsjgToVKiW6qfFs';
  static const String _geminiModel = 'gemini-3.1-pro-preview';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  PlaylistGeneratorService(this._api, this._audius, this._db)
      : super(const GeneratorState());

  // ─── Main entry: user sends a prompt ────────────────────────────────────────

  Future<void> handlePrompt(String userPrompt) async {
    if (userPrompt.trim().isEmpty) return;

    // Add user message to chat
    final updatedMessages = [
      ...state.messages,
      ChatMessage(text: userPrompt, isUser: true),
    ];

    state = state.copyWith(
      status: GeneratorStatus.thinking,
      statusMessage: 'Understanding your vibe...',
      messages: updatedMessages,
      result: null,
      error: null,
    );

    try {
      // Step 1: Ask Gemini to parse the prompt into search queries
      final parsed = await _parsePromptWithGemini(userPrompt);

      state = state.copyWith(
        status: GeneratorStatus.searching,
        statusMessage: 'Finding songs for you...',
      );

      // Step 2: Run searches in parallel across both music sources
      final songs = await _fetchSongs(parsed);

      if (songs.isEmpty) {
        state = state.copyWith(
          status: GeneratorStatus.error,
          error: 'Couldn\'t find songs for that vibe. Try describing it differently!',
          messages: [
            ...updatedMessages,
            const ChatMessage(
              text: 'Hmm, I couldn\'t find songs matching that. Try something like "chill lo-fi beats" or "90s hip hop".',
              isUser: false,
            ),
          ],
        );
        return;
      }

      final playlist = GeneratedPlaylist(
        name: parsed['playlistName'] as String? ?? 'My DEN Mix',
        description: parsed['description'] as String? ?? userPrompt,
        songs: songs,
      );

      final aiMessage = parsed['reply'] as String? ??
          'Here\'s your "${playlist.name}" playlist — ${songs.length} songs ready to play!';

      state = state.copyWith(
        status: GeneratorStatus.done,
        result: playlist,
        messages: [
          ...updatedMessages,
          ChatMessage(text: aiMessage, isUser: false, playlist: playlist),
        ],
      );
    } catch (e) {
      print('[PlaylistGenerator] Error: $e');
      state = state.copyWith(
        status: GeneratorStatus.error,
        error: e.toString(),
        messages: [
          ...updatedMessages,
          const ChatMessage(
            text: 'Something went wrong. Check your connection and try again.',
            isUser: false,
          ),
        ],
      );
    }
  }

  // ─── Step 1: Gemini parses the prompt ───────────────────────────────────────

  Future<Map<String, dynamic>> _parsePromptWithGemini(String prompt) async {
    const systemPrompt = '''
You are a music playlist assistant for an app called DEN.
The user describes what kind of music they want.
You must respond ONLY with a valid JSON object — no markdown, no extra text, no code fences.

The JSON must have these exact keys:
- "playlistName": a short, catchy playlist name (max 5 words)
- "description": one sentence describing the playlist vibe
- "reply": a friendly 1-2 sentence chat reply to the user
- "jiosaavnQueries": array of 3-5 search query strings for JioSaavn (Hindi/Bollywood music API)
- "audiusGenres": array of 1-3 Audius genre strings from: ["Electronic","Rock","Metal","Alternative","Hip-Hop/Rap","Experimental","Punk","Folk","Pop","R&B/Soul","Jazz","Acoustic","Funk","Devotional","Classical","Reggae","Country","Latin"]
- "useAudius": boolean — true if English/Western music, false if Hindi/Bollywood

Example for "chill lo-fi beats for studying":
{"playlistName":"Study Lo-Fi Chill","description":"Calm lo-fi beats for deep focus.","reply":"Here's your study playlist! These chill tracks will keep you focused.","jiosaavnQueries":["lofi hindi study music","chill instrumental hindi","soft background music"],"audiusGenres":["Electronic","Acoustic"],"useAudius":true}
''';

    try {
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/' + _geminiModel + ':generateContent?key=' + _geminiApiKey;

      final response = await _dio.post(
        url,
        options: Options(headers: {'content-type': 'application/json'}),
        data: {
          'system_instruction': {
            'parts': [{'text': systemPrompt}]
          },
          'contents': [
            {
              'role': 'user',
              'parts': [{'text': prompt}]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 512,
            'responseMimeType': 'application/json',
          },
        },
      );

      final candidates = response.data['candidates'] as List;
      final text = candidates.first['content']['parts'].first['text'] as String;
      final clean = text.replaceAll(RegExp(r'```json|```'), '').trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (e) {
      print('[PlaylistGenerator] Gemini parse error: $e');
      return {
        'playlistName': 'My Mix',
        'description': prompt,
        'reply': "Here's a playlist based on your request!",
        'jiosaavnQueries': [prompt, '$prompt songs', 'best $prompt'],
        'audiusGenres': ['Pop'],
        'useAudius': true,
      };
    }
  }

  // ─── Step 2: Fetch songs from both sources ───────────────────────────────────

  Future<List<Song>> _fetchSongs(Map<String, dynamic> parsed) async {
    final jiosaavnQueries =
        (parsed['jiosaavnQueries'] as List?)?.cast<String>() ?? [];
    final audiusGenres =
        (parsed['audiusGenres'] as List?)?.cast<String>() ?? [];
    final useAudius = parsed['useAudius'] as bool? ?? true;

    final futures = <Future<List<Song>>>[];

    // JioSaavn searches (always run — covers Hindi content)
    for (final q in jiosaavnQueries) {
      futures.add(_api.searchSongs(q, limit: 8));
    }

    // Audius genre fetch (only for English/Western requests)
    if (useAudius && audiusGenres.isNotEmpty) {
      for (final genre in audiusGenres) {
        futures.add(_audius.fetchByGenre(genre, limit: 15));
      }
    }

    final results = await Future.wait(futures);

    // Deduplicate and shuffle for a natural feel
    final seen = <String>{};
    final all = results
        .expand((l) => l)
        .where((s) => seen.add(s.id))
        .toList();

    all.shuffle();

    // Cap at 25 songs — enough for a solid playlist
    return all.take(25).toList();
  }

  // ─── Save to library ─────────────────────────────────────────────────────────

  Future<String?> savePlaylistToLibrary(GeneratedPlaylist playlist) async {
    try {
      final playlistId = await _db.createPlaylist(
        playlist.name,
        description: playlist.description,
      );
      if (playlistId.isEmpty) return null;

      // Add songs in batches to avoid hammering Firestore
      for (final song in playlist.songs) {
        await _db.addSongToPlaylist(playlistId, song);
      }

      return playlistId;
    } catch (e) {
      print('[PlaylistGenerator] Save error: $e');
      return null;
    }
  }

  void reset() {
    state = const GeneratorState();
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final playlistGeneratorProvider =
    StateNotifierProvider<PlaylistGeneratorService, GeneratorState>((ref) {
  return PlaylistGeneratorService(
    ref.read(apiServiceProvider),
    AudiusService(),
    ref.read(databaseServiceProvider),
  );
});