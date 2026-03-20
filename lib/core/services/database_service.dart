import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import 'auth_service.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? userId;

  DatabaseService(this.userId);

  // ─── LIKED SONGS ───────────────────────────────────

  Future<void> likeSong(Song song) async {
    if (userId == null) return;
    await _db
      .collection('users')
      .doc(userId)
      .collection('liked_songs')
      .doc(song.id)
      .set(song.toJson()..['likedAt'] = FieldValue.serverTimestamp());
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

  Stream<List<Song>> getLikedSongs() {
    if (userId == null) return Stream.value([]);
    return _db
      .collection('users')
      .doc(userId)
      .collection('liked_songs')
      .orderBy('likedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
        .map((d) => Song.fromJson(d.data()))
        .toList());
  }

  // ─── RECENTLY PLAYED ───────────────────────────────

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

  Stream<List<Song>> getHistory() {
    if (userId == null) return Stream.value([]);
    return _db
      .collection('users')
      .doc(userId)
      .collection('history')
      .orderBy('playedAt', descending: true)
      .limit(30)
      .snapshots()
      .map((snap) => snap.docs
        .map((d) => Song.fromJson(d.data()))
        .toList());
  }

  // ─── PLAYLISTS ─────────────────────────────────────

  Future<String> createPlaylist(String name) async {
    if (userId == null) return '';
    final doc = await _db
      .collection('users')
      .doc(userId)
      .collection('playlists')
      .add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'songCount': 0,
        'coverImage': '',
      });
    return doc.id;
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

    batch.set(songRef, song.toJson()
      ..['addedAt'] = FieldValue.serverTimestamp());
    batch.update(playlistRef, {
      'songCount': FieldValue.increment(1),
      'coverImage': song.image,
    });

    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> getPlaylists() {
    if (userId == null) return Stream.value([]);
    return _db
      .collection('users')
      .doc(userId)
      .collection('playlists')
      .orderBy('createdAt', descending: true)
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
      .map((snap) => snap.docs
        .map((d) => Song.fromJson(d.data()))
        .toList());
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final user = ref.watch(authStateProvider).value;
  return DatabaseService(user?.uid);
});

// Liked songs stream
final likedSongsProvider = StreamProvider<List<Song>>((ref) {
  return ref.watch(databaseServiceProvider).getLikedSongs();
});

// History stream
final historyProvider = StreamProvider<List<Song>>((ref) {
  return ref.watch(databaseServiceProvider).getHistory();
});

// Playlists stream
final playlistsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(databaseServiceProvider).getPlaylists();
});