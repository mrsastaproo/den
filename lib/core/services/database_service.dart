import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import 'auth_service.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? userId;

  DatabaseService(this.userId);

  // ─── LIKED SONGS ───────────────────────────────────────────

  Future<void> likeSong(Song song) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('liked_songs')
        .doc(song.id)
        .set(song.toJson()
          ..['likedAt'] = FieldValue.serverTimestamp());
  }

  Future<void> unlikeSong(String songId) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('liked_songs')
        .doc(songId)
        .delete();
  }

  Future<bool> isSongLiked(String songId) async {
    if (userId == null) return false;
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('liked_songs')
        .doc(songId)
        .get();
    return doc.exists;
  }

  /// Toggle like — returns new liked state
  Future<bool> toggleLike(Song song) async {
    if (userId == null) return false;
    final isLiked = await isSongLiked(song.id);
    if (isLiked) {
      await unlikeSong(song.id);
      return false;
    } else {
      await likeSong(song);
      return true;
    }
  }

  Stream<List<Song>> getLikedSongs() {
    if (userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('liked_songs')
        .orderBy('likedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Song.fromJson(d.data())).toList());
  }

  // ─── RECENTLY PLAYED / HISTORY ─────────────────────────────

  Future<void> addToHistory(Song song) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('history')
        .doc(song.id)
        .set(song.toJson()
          ..['playedAt'] = FieldValue.serverTimestamp());
  }

  Future<void> clearHistory() async {
    if (userId == null) return;
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('history')
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> removeFromHistory(String songId) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('history')
        .doc(songId)
        .delete();
  }

  Stream<List<Song>> getHistory() {
    if (userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('history')
        .orderBy('playedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Song.fromJson(d.data())).toList());
  }

  // ─── PLAYLISTS ─────────────────────────────────────────────

  Future<String> createPlaylist(String name,
      {String? description}) async {
    if (userId == null) return '';
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .add({
      'name': name,
      'description': description ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'songCount': 0,
      'coverImage': '',
    });
    return doc.id;
  }

  Future<void> renamePlaylist(
      String playlistId, String newName) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .doc(playlistId)
        .update({
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePlaylist(String playlistId) async {
    if (userId == null) return;

    // Delete all songs in the playlist first
    final songs = await _db
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .doc(playlistId)
        .collection('songs')
        .get();

    final batch = _db.batch();
    for (final doc in songs.docs) {
      batch.delete(doc.reference);
    }
    // Delete the playlist doc itself
    batch.delete(_db
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .doc(playlistId));

    await batch.commit();
  }

  Future<void> addSongToPlaylist(
      String playlistId, Song song) async {
    if (userId == null) return;
    final batch = _db.batch();

    final songRef = _db
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .doc(playlistId)
        .collection('songs')
        .doc(song.id);

    final playlistRef = _db
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .doc(playlistId);

    batch.set(
        songRef,
        song.toJson()
          ..['addedAt'] = FieldValue.serverTimestamp());
    batch.update(playlistRef, {
      'songCount': FieldValue.increment(1),
      'coverImage': song.image,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> removeSongFromPlaylist(
      String playlistId, String songId) async {
    if (userId == null) return;
    final batch = _db.batch();

    final songRef = _db
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .doc(playlistId)
        .collection('songs')
        .doc(songId);

    final playlistRef = _db
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .doc(playlistId);

    batch.delete(songRef);
    batch.update(playlistRef, {
      'songCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> getPlaylists() {
    if (userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  Stream<List<Song>> getPlaylistSongs(String playlistId) {
    if (userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .doc(playlistId)
        .collection('songs')
        .orderBy('addedAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Song.fromJson(d.data())).toList());
  }

  // ─── USER STATS ────────────────────────────────────────────

  Future<Map<String, int>> getUserStats() async {
    if (userId == null) return {};
    final results = await Future.wait([
      _db
          .collection('users')
          .doc(userId)
          .collection('liked_songs')
          .count()
          .get(),
      _db
          .collection('users')
          .doc(userId)
          .collection('history')
          .count()
          .get(),
      _db
          .collection('users')
          .doc(userId)
          .collection('playlists')
          .count()
          .get(),
    ]);
    return {
      'liked': results[0].count ?? 0,
      'played': results[1].count ?? 0,
      'playlists': results[2].count ?? 0,
    };
  }
}

// ─── PROVIDERS ─────────────────────────────────────────────────

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final user = ref.watch(authStateProvider).value;
  return DatabaseService(user?.uid);
});

final likedSongsProvider = StreamProvider<List<Song>>((ref) {
  return ref.watch(databaseServiceProvider).getLikedSongs();
});

final historyProvider = StreamProvider<List<Song>>((ref) {
  return ref.watch(databaseServiceProvider).getHistory();
});

final playlistsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(databaseServiceProvider).getPlaylists();
});

/// Per-song liked state — watches Firestore in real time
final songLikedProvider =
    StreamProvider.family<bool, String>((ref, songId) {
  final userId =
      ref.watch(authStateProvider).value?.uid;
  if (userId == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('liked_songs')
      .doc(songId)
      .snapshots()
      .map((snap) => snap.exists);
});