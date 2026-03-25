import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import 'api_service.dart';
import 'audius_service.dart';
import 'database_service.dart';
import 'jamendo_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

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

enum GeneratorStatus { idle, thinking, searching, done, error }

// NEW: Message type to distinguish plain chat vs playlist vs quick-replies
enum MessageType { text, playlist, quickReplies }

class ChatMessage {
  final String text;
  final bool isUser;
  final GeneratedPlaylist? playlist;
  final List<String>? quickReplies; // Suggestion chips for user to tap
  final MessageType type;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.playlist,
    this.quickReplies,
    this.type = MessageType.text,
  });
}

class GeneratorState {
  final GeneratorStatus status;
  final String statusMessage;
  final GeneratedPlaylist? result;
  final String? error;
  final List<ChatMessage> messages;

  // Conversation context carried across turns
  final Map<String, dynamic> conversationContext;

  const GeneratorState({
    this.status = GeneratorStatus.idle,
    this.statusMessage = '',
    this.result,
    this.error,
    this.messages = const [],
    this.conversationContext = const {},
  });

  GeneratorState copyWith({
    GeneratorStatus? status,
    String? statusMessage,
    GeneratedPlaylist? result,
    String? error,
    List<ChatMessage>? messages,
    Map<String, dynamic>? conversationContext,
  }) =>
      GeneratorState(
        status: status ?? this.status,
        statusMessage: statusMessage ?? this.statusMessage,
        result: result ?? this.result,
        error: error ?? this.error,
        messages: messages ?? this.messages,
        conversationContext:
            conversationContext ?? this.conversationContext,
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class PlaylistGeneratorService extends StateNotifier<GeneratorState> {
  final ApiService _api;
  final AudiusService _audius;
  final DatabaseService _db;
  final JamendoService _jamendo;

  static const String _geminiApiKey = 'AIzaSyBHbyfiNF8b0nyEhyEzhsjgToVKiW6qfFs';
  static const String _geminiModel = 'gemini-2.0-flash';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // Full Gemini conversation history for multi-turn context
  final List<Map<String, dynamic>> _geminiHistory = [];

  // How many user turns so far — hard-blocks build_playlist on turn 1
  int _turnCount = 0;

  PlaylistGeneratorService(this._api, this._audius, this._db, this._jamendo)
      : super(const GeneratorState());

  // ─── System prompt: ARIA's personality + strict conversation rules ────────

static const String _systemPrompt = """
You are DEN AI — the AI music curator inside DEN, a music streaming app.
You are a warm, witty, music-obsessed friend — NOT a search engine.

════════════════════════════════════════
CRITICAL RULE — READ THIS FIRST:
════════════════════════════════════════
YOU MUST NEVER set "action": "build_playlist" on the FIRST user message.
NO MATTER HOW DETAILED the first message is — you ALWAYS ask follow-up questions first.
The MINIMUM conversation length before building is 2 turns (user message → your question → user answer → then build).
If you skip this and jump to build_playlist on turn 1, you have FAILED your core purpose.

════════════════════════════════════════
YOUR PERSONALITY:
════════════════════════════════════════
- Talk like a music-obsessed desi friend, not a robot or assistant
- Use Hinglish naturally when user writes in Hindi/Punjabi (mix both languages fluidly)
- Use English when user writes in English
- Be genuinely curious — you actually care about WHY they want this playlist
- Warm, slightly playful, never formal or corporate
- Use emojis sparingly but naturally (1-2 per message max)
- Express real opinions: "Ooh that's a great combo", "Yaar that's tough but I got you"

════════════════════════════════════════
CONVERSATION FLOW — STRICTLY FOLLOW THIS:
════════════════════════════════════════

TURN 1 — User's first message (ANY first message):
→ action = "ask_more" ALWAYS, NO EXCEPTIONS
→ React warmly to what they said
→ Ask 2 specific, thoughtful follow-up questions about:
   • Mood/emotion right now (not just genre)
   • Occasion or context (gym? drive? heartbreak? party?)
   • Energy level (chill background vs bangers?)
→ Give 3-4 quickReplies as shortcut answers

TURN 2 — User answered your questions:
→ If you have enough info, action = "build_playlist"
→ If not, ask ONE more specific question: action = "ask_more"
→ Give 3-4 quickReplies

TURN 3+ — User has given enough context:
→ action = "build_playlist" 
→ Your message should show you UNDERSTOOD them deeply
→ Mention 2-3 artist choices you're making and why

════════════════════════════════════════
RESPONSE FORMAT — ALWAYS valid JSON:
════════════════════════════════════════

When action = "ask_more":
{
  "action": "ask_more",
  "message": "Your warm conversational response",
  "quickReplies": ["Option 1", "Option 2", "Option 3", "Option 4"]
}

When action = "build_playlist":
{
  "action": "build_playlist",
  "message": "Excited message explaining your choices",
  "playlistName": "Creative evocative name (max 5 words)",
  "description": "One vivid sentence capturing the exact vibe",
  "jiosaavnQueries": ["query1", "query2", "query3", "query4", "query5", "query6", "query7", "query8"],
  "audiusGenres": ["genre1"],
  "useAudius": false,
  "quickReplies": ["More energy", "Different language", "Older songs"]
}
""";

  // ─── Main entry: user sends a message ─────────────────────────────────────

  Future<void> handlePrompt(String userPrompt) async {
    if (userPrompt.trim().isEmpty) return;

    final updatedMessages = [
      ...state.messages,
      ChatMessage(text: userPrompt, isUser: true),
    ];

    state = state.copyWith(
      status: GeneratorStatus.thinking,
      statusMessage: _getDynamicThinkingMessage(userPrompt),
      messages: updatedMessages,
      result: null,
      error: null,
    );

    try {
      _turnCount++;

      // Add to Gemini history
      _geminiHistory.add({
        'role': 'user',
        'parts': [{'text': userPrompt}],
      });

      final response = await _callGemini();

      // ── HARD OVERRIDE: Never build on turn 1, no matter what Gemini says ──
      String action = response['action'] as String? ?? 'ask_more';
      if (_turnCount == 1 && action == 'build_playlist') {
        action = 'ask_more';
        // If Gemini gave a build response, rewrite it as a question
        if (response['message'] == null || (response['message'] as String).length < 20) {
          response['message'] = "Ooh interesting! Tell me more — what's the vibe you're going for? And are you listening while doing something specific, or just chilling? 🎵";
          response['quickReplies'] = ['Just chilling', 'Working out 💪', 'Driving 🚗', 'Studying 📚'];
        }
      }

      final message = response['message'] as String? ?? '';
      final quickReplies =
          (response['quickReplies'] as List?)?.cast<String>() ?? [];

      // Add Gemini's reply to history
      _geminiHistory.add({
        'role': 'model',
        'parts': [{'text': jsonEncode(response)}],
      });

      if (action == 'build_playlist') {
        // Time to actually search for songs
        state = state.copyWith(
          status: GeneratorStatus.searching,
          statusMessage: 'Finding the perfect songs... 🎵',
        );

        final songs = await _fetchSongs(response);

        if (songs.isEmpty) {
          final errorMsg = ChatMessage(
            text:
                'Yaar, koi song nahi mila us vibe ke liye 😅 Thoda different try kar — like "sad hindi songs" ya "punjabi party"?',
            isUser: false,
            quickReplies: ['Sad Hindi songs', 'Punjabi party', 'English chill', 'Bollywood hits'],
            type: MessageType.quickReplies,
          );
          state = state.copyWith(
            status: GeneratorStatus.done,
            messages: [...updatedMessages, errorMsg],
          );
          return;
        }

        final playlist = GeneratedPlaylist(
          name: response['playlistName'] as String? ?? 'My DEN Mix',
          description: response['description'] as String? ?? userPrompt,
          songs: songs,
        );

        final aiMessage = ChatMessage(
          text: message,
          isUser: false,
          playlist: playlist,
          quickReplies: quickReplies.isNotEmpty ? quickReplies : null,
          type: MessageType.playlist,
        );

        state = state.copyWith(
          status: GeneratorStatus.done,
          result: playlist,
          messages: [...updatedMessages, aiMessage],
        );
      } else {
        // ask_more — just send the conversational message with chips
        final aiMessage = ChatMessage(
          text: message,
          isUser: false,
          quickReplies: quickReplies.isNotEmpty ? quickReplies : null,
          type: quickReplies.isNotEmpty ? MessageType.quickReplies : MessageType.text,
        );

        state = state.copyWith(
          status: GeneratorStatus.done,
          messages: [...updatedMessages, aiMessage],
        );
      }
    } catch (e) {
      print('[PlaylistGenerator] Error: $e');

      // Friendly fallback
      final fallback = await _fallbackResponse(userPrompt, updatedMessages);
      state = fallback;
    }
  }

  String _getDynamicThinkingMessage(String prompt) {
    _turnCount; // to suppress unused
    final w = prompt.toLowerCase();
    if (w.contains('sad') || w.contains('heartbreak') || w.contains('dard')) {
      return 'Checking the deep cuts... 💔';
    }
    if (w.contains('party') || w.contains('dance') || w.contains('club')) {
      return 'Scanning for bangers... 🔥';
    }
    if (w.contains('gym') || w.contains('workout') || w.contains('hype')) {
      return 'Fueling up the gears... 😤';
    }
    if (w.contains('chill') || w.contains('lofi') || w.contains('relax')) {
      return 'Setting the mood... 😌';
    }
    return 'Analyzing the vibe... ✨';
  }

  // ─── Call Gemini with full conversation history ────────────────────────────

  Future<Map<String, dynamic>> _callGemini() async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiApiKey';

    final response = await _dio.post(
      url,
      options: Options(
        headers: {'content-type': 'application/json'},
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 25),
      ),
      data: {
        'system_instruction': {
          'parts': [{'text': _systemPrompt}]
        },
        'contents': _geminiHistory,
        'generationConfig': {
          'temperature': 0.85,
          'maxOutputTokens': 1024,
          'candidateCount': 1,
          'responseMimeType': 'application/json',
        },
      },
    );

    final candidates = response.data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini');
    }

    String text =
        candidates.first['content']['parts'].first['text'] as String;

    // Strip markdown fences if present
    text = text.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```[a-z]*\n?'), '')
          .replaceAll(RegExp(r'```$'), '')
          .trim();
    }

    // Extract JSON object
    final jsonStart = text.indexOf('{');
    final jsonEnd = text.lastIndexOf('}');
    if (jsonStart >= 0 && jsonEnd > jsonStart) {
      text = text.substring(jsonStart, jsonEnd + 1);
    }

    return jsonDecode(text) as Map<String, dynamic>;
  }

  // ─── Fetch songs from JioSaavn / Audius ───────────────────────────────────

  Future<List<Song>> _fetchSongs(Map<String, dynamic> parsed) async {
    final jiosaavnQueries =
        (parsed['jiosaavnQueries'] as List?)?.cast<String>() ?? [];
    final audiusGenres =
        (parsed['audiusGenres'] as List?)?.cast<String>() ?? [];
    final useAudius = parsed['useAudius'] as bool? ?? false;

    final futures = <Future<List<Song>>>[];

    for (final q in jiosaavnQueries) {
      futures.add(_api.searchSongs(q, limit: 8));
    }

    if (useAudius && audiusGenres.isNotEmpty) {
      for (final genre in audiusGenres) {
        futures.add(_audius.fetchByGenre(genre, limit: 15));
      }
    }

    // Fallback/Indie tracks: Jamendo API
    for (final q in jiosaavnQueries) {
      futures.add(_jamendo.fetchByQuery(q, limit: 5));
    }

    final results = await Future.wait(futures);

    final seen = <String>{};
    final totalJio = jiosaavnQueries.length;
    final totalAudius = useAudius && audiusGenres.isNotEmpty ? audiusGenres.length : 0;

    final jiosaavnResults = results.take(totalJio).expand((l) => l).toList();
    final audiusResults = results.skip(totalJio).take(totalAudius).expand((l) => l).toList();
    final jamendoResults = results.skip(totalJio + totalAudius).expand((l) => l).toList();

    audiusResults.shuffle();
    jamendoResults.shuffle();

    return [...jiosaavnResults, ...audiusResults, ...jamendoResults]
        .where((s) => seen.add(s.id))
        .take(25)
        .toList();
  }

  // ─── Fallback when Gemini fails ───────────────────────────────────────────

  Future<GeneratorState> _fallbackResponse(
      String prompt, List<ChatMessage> messages) async {

    // On turn 1, always ask questions first even in fallback
    if (_turnCount == 1) {
      return state.copyWith(
        status: GeneratorStatus.done,
        messages: [
          ...messages,
          ChatMessage(
            text:
                "Yaar, thoda bata aur — kaunsa mood hai abhi? Aur kya kar raha hai sun-te waqt? 🎵",
            isUser: false,
            quickReplies: ['Chill karna hai 😌', 'Gym / workout 💪', 'Sad mood 💔', 'Party time 🎉'],
            type: MessageType.quickReplies,
          ),
        ],
      );
    }

    final w = prompt.toLowerCase();

    final bool isPunjabi = w.contains('punjabi') || w.contains('panjabi');
    final bool isHindi =
        w.contains('hindi') || w.contains('bollywood') || w.contains('desi');
    final bool isSad = w.contains('sad') ||
        w.contains('heartbreak') ||
        w.contains('dard') ||
        w.contains('emotional');
    final bool isParty =
        w.contains('party') || w.contains('dance') || w.contains('club');
    final bool isAttitude =
        w.contains('attitude') || w.contains('aggressive') || w.contains('swag');

    // Try to build a playlist from the fallback
    List<String> queries;
    String name;
    String reply;
    List<String> chips;

    if (isPunjabi && isAttitude) {
      name = 'Punjab Attitude Mix';
      reply =
          'Pure Punjabi fire aa rahi hai! 🔥 Tera attitude wala playlist ready hai!';
      queries = [
        'Sidhu Moosewala attitude songs',
        'AP Dhillon hard hits',
        'Shubh songs 2024',
        'Karan Aujla swag',
        'punjabi gangster songs',
        'attitude punjabi 2024',
        'Diljit Dosanjh beast mode',
        'Sukha punjabi rap'
      ];
      chips = ['Make it sadder', 'Add more artists', 'English version', 'Save playlist'];
    } else if (isPunjabi && isSad) {
      name = 'Dil Toota Punjab';
      reply = 'Punjabi dard wale songs leke aaya hoon 💔 Sambhal reh yaar...';
      queries = [
        'sad punjabi songs',
        'Gurnam Bhullar emotional',
        'AP Dhillon sad songs',
        'punjabi heartbreak 2024',
        'dard punjabi songs',
        'Karan Aujla emotional',
        'punjabi breakup hits',
        'Shubh sad 2024'
      ];
      chips = ['Make it more energetic', 'Add Hindi songs too', 'Just Punjabi', 'Save playlist'];
    } else if (isHindi && isSad) {
      name = 'Broken Dil Sessions';
      reply =
          'Dil dukha hai? Main hoon na yaar 💙 Ye songs sun, thoda halka feel hoga...';
      queries = [
        'Arijit Singh sad songs',
        'heartbreak hindi 2024',
        'Atif Aslam emotional',
        'Jubin Nautiyal sad',
        'judai hindi songs',
        'dard bhari hindi songs',
        'hindi breakup 2024',
        'Darshan Raval sad'
      ];
      chips = ['Add Punjabi songs', 'Make it more upbeat', 'Old classics', 'Save playlist'];
    } else if (isHindi && isParty) {
      name = 'Bollywood Bangers';
      reply = 'Party mode ON! 💃 Bollywood ke best bangers leke aaya hoon!';
      queries = [
        'Badshah party songs 2024',
        'Yo Yo Honey Singh dance',
        'hindi club hits 2024',
        'Bollywood dance floor',
        'DJ remix hindi',
        'Nucleya songs',
        'bass hindi songs 2024',
        'trending bollywood party'
      ];
      chips = ['Add Punjabi mix', 'More old songs', 'English remix', 'Save playlist'];
    } else {
      // Generic — just try to build something
      name = 'Your Personal Mix';
      reply = "Yaar, thoda net slow tha but maine kuch dhundha hai tere liye 🎵";
      queries = [
        prompt,
        '$prompt songs 2024',
        '$prompt hits',
        '$prompt best tracks',
        '$prompt popular songs',
        'top $prompt',
        'best $prompt playlist',
        '$prompt trending'
      ];
      chips = ['More like this', 'Different language', 'More energy', 'Save playlist'];
    }

    try {
      state = state.copyWith(
        status: GeneratorStatus.searching,
        statusMessage: 'Finding songs...',
        messages: messages,
      );

      final parsed = {
        'jiosaavnQueries': queries,
        'audiusGenres': ['Pop'],
        'useAudius': false,
        'playlistName': name,
        'description': 'Curated for your vibe.',
      };

      final songs = await _fetchSongs(parsed);

      if (songs.isNotEmpty) {
        final playlist = GeneratedPlaylist(
          name: name,
          description: 'A $prompt playlist curated just for you.',
          songs: songs,
        );
        return state.copyWith(
          status: GeneratorStatus.done,
          result: playlist,
          messages: [
            ...messages,
            ChatMessage(
              text: reply,
              isUser: false,
              playlist: playlist,
              quickReplies: chips,
              type: MessageType.playlist,
            ),
          ],
        );
      }
    } catch (_) {}

    return state.copyWith(
      status: GeneratorStatus.error,
      messages: [
        ...messages,
        ChatMessage(
          text:
              'Yaar connection mein kuch dikkat aa gayi 😅 Ek baar phir try kar!',
          isUser: false,
          quickReplies: ['Try again', 'Punjabi songs', 'Hindi hits', 'Chill vibes'],
          type: MessageType.quickReplies,
        ),
      ],
    );
  }

  // ─── Save to library ──────────────────────────────────────────────────────

  Future<String?> savePlaylistToLibrary(GeneratedPlaylist playlist) async {
    try {
      final playlistId = await _db.createPlaylist(
        playlist.name,
        description: playlist.description,
      );
      if (playlistId.isEmpty) return null;

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
    _geminiHistory.clear();
    _turnCount = 0;
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
    ref.read(jamendoServiceProvider),
  );
});