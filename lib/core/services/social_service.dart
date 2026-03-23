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

  /// Decline a friend request: simply deletes the request document.
  Future<void> declineFriendRequest(String fromUid) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('received_requests')
        .doc(fromUid)
        .delete();
  }

  /// Remove an existing friend from both sides.
  Future<void> removeFriend(String friendUid) async {
    if (userId == null) return;
    final batch = _db.batch();
    batch.delete(_db.collection('users').doc(userId).collection('friends').doc(friendUid));
    batch.delete(_db.collection('users').doc(friendUid).collection('friends').doc(userId));
    await batch.commit();
  }

  // ─── BLOCKING ──────────────────────────────────────────────

  Future<void> blockUser(String targetUid) async {
    if (userId == null) return;
    await _db.collection('users').doc(userId).collection('blocked').doc(targetUid).set({
      'blockedAt': FieldValue.serverTimestamp(),
    });
    // Also remove as friend if they were one
    await removeFriend(targetUid);
  }

  Future<void> unblockUser(String targetUid) async {
    if (userId == null) return;
    await _db.collection('users').doc(userId).collection('blocked').doc(targetUid).delete();
  }

  Stream<bool> isBlocked(String targetUid) {
    if (userId == null) return Stream.value(false);
    return _db
        .collection('users')
        .doc(userId)
        .collection('blocked')
        .doc(targetUid)
        .snapshots()
        .map((snap) => snap.exists);
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
        .asyncMap((snap) async {
          final List<Map<String, dynamic>> results = [];
          for (var d in snap.docs) {
            final data = d.data();
            final fromUid = data['fromUid'] ?? d.id;
            final userDoc = await _db.collection('users').doc(fromUid).get();
            final userData = userDoc.data() ?? {};
            results.add({
              'uid': fromUid,
              ...data,
              'username': userData['username'] ?? fromUid,
              'displayName': userData['displayName'] ?? 'User',
              'photoUrl': userData['photoUrl'],
            });
          }
          return results;
        });
  }

  Stream<List<Map<String, dynamic>>> getFriends() {
    if (userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(userId)
        .collection('friends')
        .snapshots()
        .asyncMap((snap) async {
          final List<Map<String, dynamic>> results = [];
          for (var d in snap.docs) {
            final friendUid = d.id;
            final userDoc = await _db.collection('users').doc(friendUid).get();
            final userData = userDoc.data() ?? {};
            results.add({
              'uid': friendUid,
              ...d.data(),
              'username': userData['username'] ?? friendUid,
              'displayName': userData['displayName'],
              'photoUrl': userData['photoUrl'],
            });
          }
          return results;
        });
  }

  // ─── PRESENCE ──────────────────────────────────────────────────

  /// Update online state with optional status (Online, Away, Busy) and current song info
  Future<void> updatePresence(bool isOnline, {String? status, Map<String, dynamic>? nowPlaying}) async {
    if (userId == null) return;
    try {
      await _db.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'presenceStatus': status ?? (isOnline ? 'Online' : 'Offline'),
        'lastSeen': FieldValue.serverTimestamp(),
        if (nowPlaying != null) 'nowPlaying': nowPlaying,
      });
    } catch (e) {
      // Ignore if document not created yet
    }
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    await updatePresence(isOnline);
  }

  Stream<Map<String, dynamic>?> getUserProfileStream(String targetUid) {
    return _db.collection('users').doc(targetUid).snapshots().map((s) => s.data());
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

final otherUserProfileProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, targetUid) {
  return ref.watch(socialServiceProvider).getUserProfileStream(targetUid);
});

final isBlockedProvider = StreamProvider.family<bool, String>((ref, targetUid) {
  return ref.watch(socialServiceProvider).isBlocked(targetUid);
});
