import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

class SocialService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? userId;

  SocialService(this.userId);

  // ─── USERNAME MANAGEMENT ───────────────────────────────────

  /// Check if a username is already taken in the global `usernames` collection.
  Future<bool> isUsernameAvailable(String username) async {
    final doc = await _db.collection('usernames').doc(username.toLowerCase()).get();
    return !doc.exists;
  }

  /// Looks up a exact username string to get the user's uid
  Future<String?> getUidByUsername(String username) async {
    final doc = await _db.collection('usernames').doc(username.toLowerCase().trim()).get();
    if (doc.exists) {
      return doc.data()?['uid'] as String?;
    }
    return null;
  }

  /// Claims a unique username by writing to the username index and user profile.
  Future<bool> claimUsername(String username, String displayName, String? photoUrl) async {
    if (userId == null) return false;
    final normalized = username.toLowerCase().trim();

    try {
      final docRef = _db.collection('usernames').doc(normalized);
      
      // Use transaction to prevent race conditions during claim
      return await _db.runTransaction<bool>((transaction) async {
        final doc = await transaction.get(docRef);
        if (doc.exists) return false; // Taken!

        // 1. Claim in usernames
        transaction.set(docRef, {'uid': userId});

        // 2. Write details into user doc
        transaction.set(_db.collection('users').doc(userId), {
          'username': username,
          'displayName': displayName,
          'photoUrl': photoUrl ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return true;
      });
    } catch (e) {
      print('[SocialService] Claim username error: $e');
      return false;
    }
  }

  /// Get current user profile by uid
  Stream<Map<String, dynamic>?> getCurrentUserProfile() {
    if (userId == null) return Stream.value(null);
    return _db.collection('users').doc(userId).snapshots().map((snap) => snap.data());
  }

  // ─── SEARCH ────────────────────────────────────────────────

  /// Search users strictly matching or starting with the query string.
  Future<List<Map<String, dynamic>>> searchUsersByUsername(String query) async {
    if (query.isEmpty) return [];
    
    final snap = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();

    return snap.docs
        .where((d) => d.id != userId) // exclude self
        .map((d) => {'uid': d.id, ...d.data()})
        .toList();
  }

  // ─── FRIEND REQUESTS ───────────────────────────────────────

  /// Send a Request to item user. Creates a sub-collection entry.
  Future<void> sendFriendRequest(String targetUid) async {
    if (userId == null || targetUid == userId) return;

    final requestRef = _db
        .collection('users')
        .doc(targetUid)
        .collection('received_requests')
        .doc(userId);

    await requestRef.set({
      'fromUid': userId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accepts request: Adds reciprocal nodes inside `friends` sub collections.
  Future<void> acceptFriendRequest(String fromUid) async {
    if (userId == null) return;

    final batch = _db.batch();

    // 1. Add for self
    batch.set(
        _db.collection('users').doc(userId).collection('friends').doc(fromUid),
        {'addedAt': FieldValue.serverTimestamp()});

    // 2. Add for target
    batch.set(
        _db.collection('users').doc(fromUid).collection('friends').doc(userId),
        {'addedAt': FieldValue.serverTimestamp()});

    // 3. Delete the request
    batch.delete(_db
        .collection('users')
        .doc(userId)
        .collection('received_requests')
        .doc(fromUid));

    await batch.commit();
  }

  /// Listen for incoming friend requests
  Stream<List<Map<String, dynamic>>> getIncomingRequests() {
    if (userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('received_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  Stream<List<Map<String, dynamic>>> getFriends() {
    if (userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('friends')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }
}

// ─── PROVIDERS ────────────────────────────────────────────────

final socialServiceProvider = Provider<SocialService>((ref) {
  final user = ref.watch(authStateProvider).value;
  return SocialService(user?.uid);
});

final incomingRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(socialServiceProvider).getIncomingRequests();
});

final friendsListProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(socialServiceProvider).getFriends();
});

final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(socialServiceProvider).getCurrentUserProfile();
});
