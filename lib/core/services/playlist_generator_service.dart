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
    // The full prompt is sent as a single user message — Gemini Flash
    // handles instruction-following best when it's all in one message.
    final fullPrompt = """
You are a world-class music curator AI for DEN, a music streaming app.
A user wants a playlist. Analyze their request deeply — detect language preference,
energy level, mood, genre, era, and specific artists they likely want.

YOUR JOB: Return a JSON object that will be used to search JioSaavn (Indian music API)
and Audius (Western music API) to find EXACTLY the songs the user wants.

CRITICAL RULES FOR jiosaavnQueries:
1. Generate 8 SPECIFIC queries — each should find DIFFERENT songs
2. Use REAL popular artist names the user likely wants
3. Mix: artist-specific queries + mood/vibe queries + era queries
4. For Punjabi requests: AP Dhillon, Sidhu Moosewala, Shubh, Karan Aujla, Diljit Dosanjh, Imran Khan, Sukha, Gurnam Bhullar
5. For Hindi requests: Arijit Singh, Badshah, Yo Yo Honey Singh, Divine, Nucleya, Jubin Nautiyal, Atif Aslam
6. For party/dance: add "DJ remix", "club hits", "dance floor bangers"  
7. For sad/emotional: add "heartbreak", "judai", "dard", "emotional hits"
8. For attitude/aggressive: add "attitude", "swag", "beast", "gangster"
9. NEVER use keyword-only queries like "fast punjabi" — always add artist names or specific descriptors
10. Include year "2024" or "2023" in some queries for recency

Return ONLY this JSON (no markdown, no explanation, no code fences):
{
  "playlistName": "creative name (max 4 words, NOT My Mix)",
  "description": "one punchy sentence about the exact vibe",
  "reply": "enthusiastic reply in the user's language vibe — if they asked for Punjabi music be a bit desi/fun",
  "jiosaavnQueries": ["query1", "query2", "query3", "query4", "query5", "query6", "query7", "query8"],
  "audiusGenres": ["genre1"],
  "useAudius": false
}

useAudius = false for Punjabi/Hindi/Indian music
useAudius = true for English/Western/K-pop/Spanish music

User request: "$prompt"
""";

    try {
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/'
          + _geminiModel
          + ':generateContent?key='
          + _geminiApiKey;

      final response = await _dio.post(
        url,
        options: Options(
          headers: {'content-type': 'application/json'},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
        data: {
          'contents': [
            {
              'role': 'user',
              'parts': [{'text': fullPrompt}]
            }
          ],
          'generationConfig': {
            'temperature': 0.9,
            'maxOutputTokens': 1024,
            'candidateCount': 1,
          },
        },
      );

      final candidates = response.data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('No candidates returned from Gemini');
      }

      final text = candidates.first['content']['parts'].first['text'] as String;

      // Strip any accidental markdown fences
      String clean = text.trim();
      if (clean.startsWith('```')) {
        clean = clean.replaceAll(RegExp(r'^```[a-z]*\n?'), '').replaceAll(RegExp(r'```\$'), '').trim();
      }

      // Extract JSON if wrapped in other text
      final jsonStart = clean.indexOf('{');
      final jsonEnd = clean.lastIndexOf('}');
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        clean = clean.substring(jsonStart, jsonEnd + 1);
      }

      final parsed = jsonDecode(clean) as Map<String, dynamic>;

      // Validate required fields exist
      if (parsed['jiosaavnQueries'] == null || parsed['playlistName'] == null) {
        throw Exception('Invalid response structure from Gemini');
      }

      print('[PlaylistGenerator] Gemini success: ' + (parsed['playlistName'] ?? ''));
      print('[PlaylistGenerator] Queries: ' + parsed['jiosaavnQueries'].toString());
      return parsed;

    } catch (e) {
      print('[PlaylistGenerator] Gemini error: \$e');
      // Smart fallback based on prompt keywords
      final w = prompt.toLowerCase();
      final isPunjabi = w.contains('punjabi') || w.contains('panjabi') || w.contains('punjab');
      final isHindi = w.contains('hindi') || w.contains('bollywood') || w.contains('desi');
      final isSad = w.contains('sad') || w.contains('heartbreak') || w.contains('emotional') || w.contains('dard');
      final isParty = w.contains('party') || w.contains('dance') || w.contains('club') || w.contains('dj');
      final isAttitude = w.contains('attitude') || w.contains('aggressive') || w.contains('hard') || w.contains('swag');

      List<String> queries;
      String name;
      String reply;

      if (isPunjabi && isAttitude) {
        name = 'Punjab Attitude Mix';
        reply = 'Pure Punjabi fire coming your way! 🔥';
        queries = ['Sidhu Moosewala attitude','AP Dhillon hard hits','Shubh songs 2024','Karan Aujla swag','punjabi gangster songs','attitude punjabi 2024','Diljit Dosanjh beast','Sukha punjabi rap'];
      } else if (isPunjabi && isSad) {
        name = 'Dil Toota Punjab';
        reply = 'Punjabi dard songs coming right up 💔';
        queries = ['sad punjabi songs','Gurnam Bhullar emotional','AP Dhillon sad','punjabi heartbreak 2024','dard punjabi songs','Sidhu Moosewala emotional','Karan Aujla sad songs','punjabi breakup hits'];
      } else if (isPunjabi) {
        name = 'Punjab Vibes';
        reply = 'Best Punjabi tracks for you! 🎵';
        queries = ['AP Dhillon hits','Sidhu Moosewala songs','Shubh 2024','Karan Aujla best songs','Diljit Dosanjh hits','punjabi hits 2024','Imran Khan punjabi','Gurnam Bhullar songs'];
      } else if (isHindi && isSad) {
        name = 'Broken Dil Sessions';
        reply = 'Emotional Hindi songs just for you 💙';
        queries = ['Arijit Singh sad songs','heartbreak hindi 2024','Atif Aslam emotional','Jubin Nautiyal sad','tere bina songs','judai hindi songs','dard bhari songs','hindi breakup 2024'];
      } else if (isHindi && isParty) {
        name = 'Bollywood Bangers';
        reply = 'Party ke liye best Hindi bangers! 💃';
        queries = ['Badshah party songs','Yo Yo Honey Singh dance','hindi club hits 2024','Bollywood dance floor','DJ remix hindi','party bollywood 2024','Nucleya songs','bass hindi songs'];
      } else if (isHindi) {
        name = 'Hindi Hits';
        reply = 'Best Hindi songs for your vibe! 🎶';
        queries = ['Arijit Singh hits 2024','hindi top songs 2024','Jubin Nautiyal songs','Atif Aslam best','new hindi songs','Badshah hits','trending hindi 2024','bollywood superhits'];
      } else {
        name = '\${prompt.split(' ').take(3).join(' ')} Mix';
        reply = "Here's your playlist! 🎵";
        queries = [prompt, '\$prompt songs 2024', '\$prompt hits', '\$prompt best tracks', '\$prompt top songs', '\$prompt playlist', '\$prompt music', 'best \$prompt'];
      }

      return {
        'playlistName': name,
        'description': 'A \$prompt playlist curated for you.',
        'reply': reply,
        'jiosaavnQueries': queries,
        'audiusGenres': ['Pop'],
        'useAudius': false,
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

    // Don't fully shuffle — keep JioSaavn results first (most relevant)
    // Only shuffle within the Audius portion to add variety
    final seen = <String>{};
    final jiosaavnResults = results.take(jiosaavnQueries.length)
        .expand((l) => l).toList();
    final audiusResults = results.skip(jiosaavnQueries.length)
        .expand((l) => l).toList();
    audiusResults.shuffle();

    final ordered = [...jiosaavnResults, ...audiusResults]
        .where((s) => seen.add(s.id))
        .toList();

    // Cap at 25 songs — enough for a solid playlist
    return ordered.take(25).toList();
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