import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import 'auth_service.dart';

// ─── Wrapped Data Model ───────────────────────────────────────────────────────

class WrappedStats {
  final int totalSongs;
  final int totalMinutes;
  final String topArtist;
  final String topArtistImage;
  final String topSong;
  final String topSongArtist;
  final String topSongImage;
  final String topLanguage;
  final String topLanguageEmoji;
  final String musicPersonality;
  final String personalityEmoji;
  final String personalityDesc;
  final List<Song> topSongs;         // top 5 songs
  final List<String> topArtists;     // top 5 artists
  final Map<String, int> hourMap;    // hour → play count (for peak hour)
  final String peakHour;
  final WrappedPeriod period;

  const WrappedStats({
    required this.totalSongs,
    required this.totalMinutes,
    required this.topArtist,
    required this.topArtistImage,
    required this.topSong,
    required this.topSongArtist,
    required this.topSongImage,
    required this.topLanguage,
    required this.topLanguageEmoji,
    required this.musicPersonality,
    required this.personalityEmoji,
    required this.personalityDesc,
    required this.topSongs,
    required this.topArtists,
    required this.hourMap,
    required this.peakHour,
    required this.period,
  });
}

enum WrappedPeriod { week, month, allTime }

// ─── Service ──────────────────────────────────────────────────────────────────

class WrappedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? userId;

  WrappedService(this.userId);

  Future<WrappedStats?> getStats(WrappedPeriod period) async {
    if (userId == null) return null;

    final now = DateTime.now();
    DateTime since;
    switch (period) {
      case WrappedPeriod.week:
        since = now.subtract(const Duration(days: 7));
        break;
      case WrappedPeriod.month:
        since = now.subtract(const Duration(days: 30));
        break;
      case WrappedPeriod.allTime:
        since = DateTime(2020);
        break;
    }

    // Fetch history within period
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('history')
        .where('playedAt', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('playedAt', descending: true)
        .limit(500)
        .get();

    if (snap.docs.isEmpty) return null;

    final songs = snap.docs.map((d) {
      final data = d.data();
      return _HistoryEntry(
        song: Song.fromJson(data),
        playedAt: (data['playedAt'] as Timestamp?)?.toDate() ?? now,
      );
    }).toList();

    // ── Compute stats ───────────────────────────────────────────

    // Artist frequency
    final artistCount = <String, int>{};
    final artistImages = <String, String>{};
    for (final e in songs) {
      if (e.song.artist.isNotEmpty) {
        artistCount[e.song.artist] = (artistCount[e.song.artist] ?? 0) + 1;
        if (artistImages[e.song.artist] == null && e.song.image.isNotEmpty) {
          artistImages[e.song.artist] = e.song.image;
        }
      }
    }
    final sortedArtists = artistCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topArtist = sortedArtists.isNotEmpty ? sortedArtists.first.key : 'Unknown';
    final topArtistImage = artistImages[topArtist] ?? '';
    final topArtistsList = sortedArtists.take(5).map((e) => e.key).toList();

    // Song frequency
    final songCount = <String, int>{};
    final songMap = <String, Song>{};
    for (final e in songs) {
      songCount[e.song.id] = (songCount[e.song.id] ?? 0) + 1;
      songMap[e.song.id] = e.song;
    }
    final sortedSongs = songCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSongId = sortedSongs.isNotEmpty ? sortedSongs.first.key : '';
    final topSongObj = songMap[topSongId];
    final topSongsList = sortedSongs
        .take(5)
        .map((e) => songMap[e.key]!)
        .toList();

    // Language frequency
    final langCount = <String, int>{};
    for (final e in songs) {
      final lang = e.song.language.toLowerCase();
      if (lang.isNotEmpty && lang != 'unknown') {
        langCount[lang] = (langCount[lang] ?? 0) + 1;
      }
    }
    final sortedLangs = langCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topLang = sortedLangs.isNotEmpty
        ? _capitalize(sortedLangs.first.key)
        : 'Mixed';

    // Peak listening hour
    final hourCount = <int, int>{};
    for (final e in songs) {
      final h = e.playedAt.hour;
      hourCount[h] = (hourCount[h] ?? 0) + 1;
    }
    final sortedHours = hourCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final peakHourNum = sortedHours.isNotEmpty ? sortedHours.first.key : 20;
    final peakHourStr = _formatHour(peakHourNum);
    // ignore: unused_local_variable
    final hourMap = {
      for (final e in hourCount.entries) e.key.toString(): e.value
    };

    // Total minutes (avg song = 3.5 min)
    final totalMinutes = (songs.length * 3.5).round();

    // Music personality
    final personality = _computePersonality(
      topLang: topLang,
      peakHour: peakHourNum,
      totalSongs: songs.length,
      topArtist: topArtist,
      langCount: langCount,
    );

    return WrappedStats(
      totalSongs: songs.length,
      totalMinutes: totalMinutes,
      topArtist: topArtist,
      topArtistImage: topArtistImage,
      topSong: topSongObj?.title ?? 'Unknown',
      topSongArtist: topSongObj?.artist ?? '',
      topSongImage: topSongObj?.image ?? '',
      topLanguage: topLang,
      topLanguageEmoji: _langEmoji(topLang),
      musicPersonality: personality.name,
      personalityEmoji: personality.emoji,
      personalityDesc: personality.desc,
      topSongs: topSongsList,
      topArtists: topArtistsList,
      hourMap: {for (final e in hourCount.entries) e.key.toString(): e.value},
      peakHour: peakHourStr,
      period: period,
    );
  }

  // ─── Helpers ────────────────────────────────────────────────

  _Personality _computePersonality({
    required String topLang,
    required int peakHour,
    required int totalSongs,
    required String topArtist,
    required Map<String, int> langCount,
  }) {
    final isNight = peakHour >= 22 || peakHour <= 4;
    final isMorning = peakHour >= 5 && peakHour <= 9;
    final isPunjabi = topLang.toLowerCase().contains('punjabi');
    final isHindi = topLang.toLowerCase() == 'hindi';
    final isEnglish = topLang.toLowerCase() == 'english';
    final isMultilingual = langCount.length >= 3;

    if (isNight && isPunjabi) return _Personality('Midnight Punjabi 🌙', '🔥', 'Desi nights, pure vibes. You\'re a real one.');
    if (isNight) return _Personality('Midnight Soul', '🌙', 'You come alive after dark. Music is your 2AM therapy.');
    if (isMorning && isHindi) return _Personality('Subah Ka Rockstar', '🌅', 'Early riser, Bollywood blaster. You slay before 9AM.');
    if (isPunjabi && totalSongs > 100) return _Personality('Punjab Ka Raja', '👑', 'Pure Punjabi energy. You\'ve got the culture running in your veins.');
    if (isPunjabi) return _Personality('Desi Swagger', '💫', 'Punjabi at heart, fire in the playlist.');
    if (isEnglish && isNight) return _Personality('Night Owl Headbanger', '🦉', 'Late nights, Western hits. You\'ve got global taste.');
    if (isMultilingual) return _Personality('Global Listener', '🌍', 'No language limits you. World music is your playground.');
    if (isHindi && totalSongs > 100) return _Personality('Bollywood Obsessed', '🎬', 'Lights, camera, action — your life has a Bollywood soundtrack.');
    if (totalSongs > 200) return _Personality('Music Addict', '🎧', 'You breathe music. This isn\'t a hobby, it\'s a lifestyle.');
    return _Personality('Vibe Curator', '✨', 'Thoughtful, eclectic, always on point. Your taste is unmatched.');
  }

  String _langEmoji(String lang) {
    switch (lang.toLowerCase()) {
      case 'punjabi': return '🎺';
      case 'hindi': return '🎵';
      case 'english': return '🎸';
      case 'tamil': return '🥁';
      case 'telugu': return '🎻';
      case 'kannada': return '🪘';
      case 'malayalam': return '🎷';
      default: return '🎶';
    }
  }

  String _formatHour(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _HistoryEntry {
  final Song song;
  final DateTime playedAt;
  _HistoryEntry({required this.song, required this.playedAt});
}

class _Personality {
  final String name;
  final String emoji;
  final String desc;
  _Personality(this.name, this.emoji, this.desc);
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final wrappedServiceProvider = Provider<WrappedService>((ref) {
  final user = ref.watch(authStateProvider).value;
  return WrappedService(user?.uid);
});

final wrappedStatsProvider = FutureProvider.family<WrappedStats?, WrappedPeriod>(
  (ref, period) => ref.watch(wrappedServiceProvider).getStats(period),
);