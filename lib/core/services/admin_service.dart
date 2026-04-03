import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

// ─────────────────────────────────────────────────────────────
// ADMIN GUARD — only mrsastapro@gmail.com
// ─────────────────────────────────────────────────────────────

const _adminEmail = 'mrsastapro@gmail.com';

bool isAdmin(User? user) =>
    user != null && user.email?.toLowerCase() == _adminEmail;

final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  return isAdmin(user);
});

// ─────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────

class AdminUser {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final bool isBanned;
  final String banReason;
  final DateTime? createdAt;
  final DateTime? lastActive;
  final DateTime? bannedAt;
  final String bannedBy;
  final bool isOnline;
  final int likedSongs;
  final int playlists;
  final int totalPlays;

  const AdminUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.isBanned,
    required this.banReason,
    this.createdAt,
    this.lastActive,
    this.bannedAt,
    this.bannedBy = '',
    this.isOnline = false,
    required this.likedSongs,
    required this.playlists,
    required this.totalPlays,
  });

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AdminUser(
      uid: doc.id,
      email: d['email'] ?? '',
      displayName: d['displayName'] ?? '',
      photoUrl: d['photoUrl'] ?? d['photoURL'] ?? '',
      isBanned: d['isBanned'] ?? false,
      banReason: d['banReason'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      lastActive: (d['lastActive'] as Timestamp?)?.toDate(),
      bannedAt: (d['bannedAt'] as Timestamp?)?.toDate(),
      bannedBy: d['bannedBy'] ?? '',
      isOnline: d['isOnline'] ?? false,
      likedSongs: d['likedSongs'] ?? 0,
      playlists: d['playlists'] ?? 0,
      totalPlays: d['totalPlays'] ?? 0,
    );
  }
}

class AppAnnouncement {
  final String id;
  final String title;
  final String message;
  final String type; // info | warning | success | promo
  final bool isActive;
  final DateTime? createdAt;
  final String createdBy;

  const AppAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isActive,
    this.createdAt,
    required this.createdBy,
  });

  factory AppAnnouncement.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AppAnnouncement(
      id: doc.id,
      title: d['title'] ?? '',
      message: d['message'] ?? '',
      type: d['type'] ?? 'info',
      isActive: d['isActive'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      createdBy: d['createdBy'] ?? '',
    );
  }
}

class FeaturedBanner {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String actionQuery;
  final bool isActive;
  final int order;

  const FeaturedBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.actionQuery,
    required this.isActive,
    required this.order,
  });

  factory FeaturedBanner.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return FeaturedBanner(
      id: doc.id,
      title: d['title'] ?? '',
      subtitle: d['subtitle'] ?? '',
      imageUrl: d['imageUrl'] ?? '',
      actionQuery: d['actionQuery'] ?? '',
      isActive: d['isActive'] ?? false,
      order: d['order'] ?? 0,
    );
  }
}

class AppConfig {
  final bool maintenanceMode;
  final String maintenanceMessage;
  final bool forceUpdate;
  final String minVersion;
  final String latestVersion;
  final String updateMessage;
  final bool audiusEnabled;
  final bool jiosaavnEnabled;
  final int maxSearchResults;
  final int maxHistoryItems;
  final String welcomeMessage;
  final bool registrationEnabled;

  const AppConfig({
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.forceUpdate,
    required this.minVersion,
    required this.latestVersion,
    required this.updateMessage,
    required this.audiusEnabled,
    required this.jiosaavnEnabled,
    required this.maxSearchResults,
    required this.maxHistoryItems,
    required this.welcomeMessage,
    required this.registrationEnabled,
  });

  factory AppConfig.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AppConfig(
      maintenanceMode: d['maintenanceMode'] ?? false,
      maintenanceMessage:
          d['maintenanceMessage'] ?? 'We\'re performing maintenance. Back soon!',
      forceUpdate: d['forceUpdate'] ?? false,
      minVersion: d['minVersion'] ?? '1.0.0',
      latestVersion: d['latestVersion'] ?? '1.0.0',
      updateMessage: d['updateMessage'] ?? 'A new version is available.',
      audiusEnabled: d['audiusEnabled'] ?? true,
      jiosaavnEnabled: d['jiosaavnEnabled'] ?? true,
      maxSearchResults: d['maxSearchResults'] ?? 50,
      maxHistoryItems: d['maxHistoryItems'] ?? 50,
      welcomeMessage: d['welcomeMessage'] ?? 'Welcome to DEN!',
      registrationEnabled: d['registrationEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'maintenanceMode': maintenanceMode,
        'maintenanceMessage': maintenanceMessage,
        'forceUpdate': forceUpdate,
        'minVersion': minVersion,
        'latestVersion': latestVersion,
        'updateMessage': updateMessage,
        'audiusEnabled': audiusEnabled,
        'jiosaavnEnabled': jiosaavnEnabled,
        'maxSearchResults': maxSearchResults,
        'maxHistoryItems': maxHistoryItems,
        'welcomeMessage': welcomeMessage,
        'registrationEnabled': registrationEnabled,
      };
}

class AdminStats {
  final int totalUsers;
  final int activeToday;
  final int totalPlays;
  final int totalLikes;
  final int totalPlaylists;
  final int bannedUsers;
  final int activeAnnouncements;
  final DateTime? lastUpdated;

  const AdminStats({
    required this.totalUsers,
    required this.activeToday,
    required this.totalPlays,
    required this.totalLikes,
    required this.totalPlaylists,
    required this.bannedUsers,
    required this.activeAnnouncements,
    this.lastUpdated,
  });

  factory AdminStats.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AdminStats(
      totalUsers: d['totalUsers'] ?? 0,
      activeToday: d['activeToday'] ?? 0,
      totalPlays: d['totalPlays'] ?? 0,
      totalLikes: d['totalLikes'] ?? 0,
      totalPlaylists: d['totalPlaylists'] ?? 0,
      bannedUsers: d['bannedUsers'] ?? 0,
      activeAnnouncements: d['activeAnnouncements'] ?? 0,
      lastUpdated: (d['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }
}

/// Represents a single broadcast notification record stored in Firestore.
class BroadcastNotification {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String? link;
  final DateTime? sentAt;
  final String sentBy;
  final String status; // pending | sent | failed

  const BroadcastNotification({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.link,
    this.sentAt,
    required this.sentBy,
    required this.status,
  });

  factory BroadcastNotification.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return BroadcastNotification(
      id: doc.id,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      imageUrl: d['imageUrl'] as String?,
      link: d['link'] as String?,
      sentAt: (d['sentAt'] as Timestamp?)?.toDate(),
      sentBy: d['sentBy'] ?? '',
      status: d['status'] ?? 'pending',
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ADMIN SERVICE
// ─────────────────────────────────────────────────────────────

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── GUARD ──────────────────────────────────────────────────
  bool get _isAdmin =>
      _auth.currentUser?.email?.toLowerCase() == _adminEmail;

  void _checkAdmin() {
    if (!_isAdmin) throw Exception('Unauthorized: Admin access only');
  }

  // ── STATS ──────────────────────────────────────────────────

  Stream<AdminStats> getStats() {
    _checkAdmin();
    return _db
        .collection('admin')
        .doc('stats')
        .snapshots()
        .map(AdminStats.fromFirestore);
  }

  Future<void> refreshStats() async {
    _checkAdmin();
    final usersSnap = await _db.collection('users').count().get();
    final bannedSnap = await _db
        .collection('users')
        .where('isBanned', isEqualTo: true)
        .count()
        .get();
    final annSnap = await _db
        .collection('announcements')
        .where('isActive', isEqualTo: true)
        .count()
        .get();

    // Recalculate aggregate totals across all users
    int totalPlays = 0;
    int totalLikes = 0;
    int totalPlaylists = 0;
    final allUsers = await _db.collection('users').limit(500).get();
    for (final doc in allUsers.docs) {
      final d = doc.data();
      totalPlays += (d['totalPlays'] as int? ?? 0);
      totalLikes += (d['likedSongs'] as int? ?? 0);
      totalPlaylists += (d['playlists'] as int? ?? 0);
    }

    // Count active-today: users whose lastActive timestamp is within 24h
    final since = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)));
    final activeTodaySnap = await _db
        .collection('users')
        .where('lastActive', isGreaterThan: since)
        .count()
        .get();

    await _db.collection('admin').doc('stats').set({
      'totalUsers': usersSnap.count ?? 0,
      'bannedUsers': bannedSnap.count ?? 0,
      'activeAnnouncements': annSnap.count ?? 0,
      'totalPlays': totalPlays,
      'totalLikes': totalLikes,
      'totalPlaylists': totalPlaylists,
      'activeToday': activeTodaySnap.count ?? 0,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _logActivity('refresh_stats', {
      'totalUsers': usersSnap.count ?? 0,
    });
  }

  // ── USERS ──────────────────────────────────────────────────

  Stream<List<AdminUser>> getUsers({int limit = 100}) {
    _checkAdmin();
    return _db.collection('users').limit(limit).snapshots().map((snap) {
      final users = snap.docs.map(AdminUser.fromFirestore).toList();
      users.sort((a, b) {
        final da = a.createdAt ?? DateTime(2000);
        final db = b.createdAt ?? DateTime(2000);
        return db.compareTo(da);
      });
      return users;
    }).handleError((error) {
      print('[ADMIN_SERVICE] getUsers error: $error');
      return <AdminUser>[];
    });
  }

  /// Paginated fetch approach instead of streams for massive datasets
  Future<Map<String, dynamic>> fetchUsersPaginated({DocumentSnapshot? startAfter, int limit = 50}) async {
    _checkAdmin();
    var query = _db.collection('users').orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    try {
      final snap = await query.get();
      final users = snap.docs.map(AdminUser.fromFirestore).toList();
      return {
        'users': users,
        'lastDoc': snap.docs.isNotEmpty ? snap.docs.last : null,
      };
    } catch (e) {
      print('[ADMIN_SERVICE] fetchUsersPaginated error: $e');
      throw Exception('Failed to load users: $e');
    }
  }

  /// Server-side search by email prefix (Firestore range query).
  Stream<List<AdminUser>> searchUsers(String query) {
    _checkAdmin();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getUsers();
    return _db
        .collection('users')
        .orderBy('email')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(AdminUser.fromFirestore).toList())
        .handleError((error) {
          print('[ADMIN_SERVICE] searchUsers error: $error');
          return <AdminUser>[];
        });
  }

  Future<void> banUser(String uid, String reason) async {
    _checkAdmin();
    await _db.collection('users').doc(uid).set({
      'isBanned': true,
      'banReason': reason,
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': _auth.currentUser?.email,
    }, SetOptions(merge: true));
    await _db.collection('admin').doc('stats').set(
        {'bannedUsers': FieldValue.increment(1)}, SetOptions(merge: true));
    await _logActivity('ban_user', {'uid': uid, 'reason': reason});
  }

  Future<void> unbanUser(String uid) async {
    _checkAdmin();
    await _db.collection('users').doc(uid).update({
      'isBanned': false,
      'banReason': '',
      'bannedAt': FieldValue.delete(),
      'bannedBy': FieldValue.delete(),
    });
    await _db.collection('admin').doc('stats').set(
        {'bannedUsers': FieldValue.increment(-1)}, SetOptions(merge: true));
    await _logActivity('unban_user', {'uid': uid});
  }

  Future<void> syncUserStats(String uid) async {
    _checkAdmin();
    final results = await Future.wait([
      _db.collection('users').doc(uid).collection('liked_songs').count().get(),
      _db.collection('users').doc(uid).collection('history').count().get(),
      _db.collection('users').doc(uid).collection('playlists').count().get(),
    ]);

    await _db.collection('users').doc(uid).update({
      'likedSongs': results[0].count ?? 0,
      'totalPlays': results[1].count ?? 0,
      'playlists': results[2].count ?? 0,
    });
  }

  Future<void> syncAllUsersStats() async {
    _checkAdmin();
    final users = await _db.collection('users').limit(500).get();
    for (final user in users.docs) {
      await syncUserStats(user.id);
    }
    await _logActivity('sync_all_stats', {'userCount': users.size});
  }

  Future<void> deleteUserData(String uid) async {
    _checkAdmin();
    for (final sub in ['liked_songs', 'history', 'playlists']) {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection(sub)
          .limit(500)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _db.collection('users').doc(uid).delete();
    await _logActivity('delete_user_data', {'uid': uid});
  }

  Future<void> syncUserProfile(
      String uid, String email, String displayName, String photoUrl) async {
    await _db.collection('users').doc(uid).set({
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── ANNOUNCEMENTS ──────────────────────────────────────────

  Stream<List<AppAnnouncement>> getAnnouncements() {
    _checkAdmin();
    return _db
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(AppAnnouncement.fromFirestore).toList());
  }

  Stream<List<AppAnnouncement>> getActiveAnnouncements() {
    return _db
        .collection('announcements')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots()
        .map((snap) =>
            snap.docs.map(AppAnnouncement.fromFirestore).toList());
  }

  Future<void> createAnnouncement({
    required String title,
    required String message,
    required String type,
    bool isActive = true,
  }) async {
    _checkAdmin();
    await _db.collection('announcements').add({
      'title': title,
      'message': message,
      'type': type,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _auth.currentUser?.email,
    });
    await _logActivity('create_announcement', {'title': title, 'type': type});
  }

  Future<void> updateAnnouncement(String id,
      {String? title, String? message, String? type, bool? isActive}) async {
    _checkAdmin();
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (message != null) updates['message'] = message;
    if (type != null) updates['type'] = type;
    if (isActive != null) updates['isActive'] = isActive;
    await _db.collection('announcements').doc(id).update(updates);
  }

  Future<void> deleteAnnouncement(String id) async {
    _checkAdmin();
    await _db.collection('announcements').doc(id).delete();
    await _logActivity('delete_announcement', {'id': id});
  }

  // ── FEATURED BANNERS ───────────────────────────────────────

  Stream<List<FeaturedBanner>> getFeaturedBanners() {
    _checkAdmin();
    return _db
        .collection('featured_banners')
        .orderBy('order')
        .snapshots()
        .map((snap) =>
            snap.docs.map(FeaturedBanner.fromFirestore).toList());
  }

  Future<void> createBanner({
    required String title,
    required String subtitle,
    required String imageUrl,
    required String actionQuery,
    bool isActive = true,
    int order = 0,
  }) async {
    _checkAdmin();
    await _db.collection('featured_banners').add({
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'actionQuery': actionQuery,
      'isActive': isActive,
      'order': order,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _logActivity('create_banner', {'title': title});
  }

  Future<void> updateBanner(String id, Map<String, dynamic> data) async {
    _checkAdmin();
    await _db.collection('featured_banners').doc(id).update(data);
  }

  Future<void> deleteBanner(String id) async {
    _checkAdmin();
    await _db.collection('featured_banners').doc(id).delete();
    await _logActivity('delete_banner', {'id': id});
  }

  // ── APP CONFIG ─────────────────────────────────────────────

  Stream<AppConfig> getAppConfig() {
    _checkAdmin();
    return _db
        .collection('admin')
        .doc('config')
        .snapshots()
        .map(AppConfig.fromFirestore);
  }

  Future<AppConfig?> fetchAppConfig() async {
    final doc = await _db.collection('admin').doc('config').get();
    if (!doc.exists) return null;
    return AppConfig.fromFirestore(doc);
  }

  Future<void> updateAppConfig(Map<String, dynamic> updates) async {
    _checkAdmin();
    await _db
        .collection('admin')
        .doc('config')
        .set(updates, SetOptions(merge: true));
    await _logActivity('update_config', updates);
  }

  // ── CONTENT CURATION ───────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getCuratedSections() {
    _checkAdmin();
    return _db
        .collection('curated_sections')
        .orderBy('order')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> createCuratedSection({
    required String title,
    required String subtitle,
    required String query,
    required String style,
    required int order,
    bool isActive = true,
  }) async {
    _checkAdmin();
    await _db.collection('curated_sections').add({
      'title': title,
      'subtitle': subtitle,
      'query': query,
      'style': style,
      'order': order,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _logActivity('create_curated_section', {'title': title});
  }

  Future<void> updateCuratedSection(
      String id, Map<String, dynamic> data) async {
    _checkAdmin();
    await _db.collection('curated_sections').doc(id).update(data);
  }

  Future<void> deleteCuratedSection(String id) async {
    _checkAdmin();
    await _db.collection('curated_sections').doc(id).delete();
    await _logActivity('delete_curated_section', {'id': id});
  }

  // ── BROADCAST NOTIFICATIONS ────────────────────────────────

  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    String? imageUrl,
    String? link,
  }) async {
    _checkAdmin();
    await _db.collection('broadcasts').add({
      'title': title,
      'body': body,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      if (link != null && link.isNotEmpty) 'link': link,
      'sentAt': FieldValue.serverTimestamp(),
      'sentBy': _auth.currentUser?.email,
      'status': 'pending',
    });
    await _logActivity('send_broadcast', {'title': title, 'body': body});
  }

  /// Returns typed broadcast objects for the admin history panel.
  Stream<List<BroadcastNotification>> getBroadcastNotifications() {
    _checkAdmin();
    return _db
        .collection('broadcasts')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map(BroadcastNotification.fromFirestore).toList());
  }

  /// Raw map stream used by the user-facing NotificationInboxScreen.
  Stream<List<Map<String, dynamic>>> getBroadcasts() {
    return _db
        .collection('broadcasts')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> deleteBroadcast(String id) async {
    _checkAdmin();
    await _db.collection('broadcasts').doc(id).delete();
    await _logActivity('delete_broadcast', {'id': id});
  }

  // ── HANDLE RESCUE ──────────────────────────────────────────

  Future<Map<String, dynamic>?> lookupHandle(String handle) async {
    _checkAdmin();
    final h = handle.trim().toLowerCase();
    final userSnap = await _db.collection('usernames').doc(h).get();
    if (!userSnap.exists) return null;

    final uid = userSnap.data()?['uid'] as String?;
    if (uid == null) return null;

    final profileSnap = await _db.collection('users').doc(uid).get();
    final profile = profileSnap.data() as Map<String, dynamic>? ?? {};

    return {
      'uid': uid,
      'email': profile['email'] ?? 'Unknown',
      'displayName': profile['displayName'] ?? 'No Name',
      'hasProfile': profileSnap.exists,
    };
  }

  Future<void> rescueHandle(String handle, String targetUid) async {
    _checkAdmin();
    final h = handle.trim().toLowerCase();
    final lookup = await lookupHandle(h);
    if (lookup == null) throw Exception('Handle not found');

    final oldUid = lookup['uid'] as String;

    final batch = _db.batch();

    // 1. Update username pointer
    batch.set(_db.collection('usernames').doc(h), {
      'uid': targetUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Update target user profile
    batch.set(_db.collection('users').doc(targetUid), {
      'username': h,
    }, SetOptions(merge: true));

    // 3. Optional: Try to migrate friends (Copy from old to new)
    final oldFriends = await _db.collection('users').doc(oldUid).collection('friends').get();
    for (final doc in oldFriends.docs) {
      batch.set(
        _db.collection('users').doc(targetUid).collection('friends').doc(doc.id),
        doc.data(),
      );
    }

    await batch.commit();
    await _logActivity('rescue_handle', {'handle': h, 'oldUid': oldUid, 'newUid': targetUid});
  }

  // ── ADMIN ACTIVITY LOG ─────────────────────────────────────

  Future<void> _logActivity(
      String action, Map<String, dynamic> details) async {
    try {
      await _db
          .collection('admin')
          .doc('logs')
          .collection('activity')
          .add({
        'action': action,
        'details': details,
        'adminEmail': _auth.currentUser?.email,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Never let logging errors propagate to the UI
    }
  }

  Stream<List<Map<String, dynamic>>> getActivityLog() {
    _checkAdmin();
    return _db
        .collection('admin')
        .doc('logs')
        .collection('activity')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────

final adminServiceProvider =
    Provider<AdminService>((ref) => AdminService());

final adminStatsProvider = StreamProvider<AdminStats>((ref) {
  if (!ref.watch(isAdminProvider)) return const Stream.empty();
  return ref.watch(adminServiceProvider).getStats();
});

final adminUsersProvider = StreamProvider<List<AdminUser>>((ref) {
  if (!ref.watch(isAdminProvider)) return const Stream.empty();
  return ref.watch(adminServiceProvider).getUsers();
});

final adminAnnouncementsProvider =
    StreamProvider<List<AppAnnouncement>>((ref) {
  if (!ref.watch(isAdminProvider)) return const Stream.empty();
  return ref.watch(adminServiceProvider).getAnnouncements();
});

final activeAnnouncementsProvider =
    StreamProvider<List<AppAnnouncement>>((ref) {
  return ref.watch(adminServiceProvider).getActiveAnnouncements();
});

final adminBannersProvider = StreamProvider<List<FeaturedBanner>>((ref) {
  if (!ref.watch(isAdminProvider)) return const Stream.empty();
  return ref.watch(adminServiceProvider).getFeaturedBanners();
});

final adminConfigProvider = StreamProvider<AppConfig>((ref) {
  if (!ref.watch(isAdminProvider)) return const Stream.empty();
  return ref.watch(adminServiceProvider).getAppConfig();
});

final adminCuratedProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  if (!ref.watch(isAdminProvider)) return const Stream.empty();
  return ref.watch(adminServiceProvider).getCuratedSections();
});

final adminActivityProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  if (!ref.watch(isAdminProvider)) return const Stream.empty();
  return ref.watch(adminServiceProvider).getActivityLog();
});

/// Typed broadcast provider for the admin Notifications tab.
final adminBroadcastsProvider =
    StreamProvider<List<BroadcastNotification>>((ref) {
  if (!ref.watch(isAdminProvider)) return const Stream.empty();
  return ref.watch(adminServiceProvider).getBroadcastNotifications();
});

/// Raw map provider used by the user-facing NotificationInboxScreen.
final broadcastsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminServiceProvider).getBroadcasts();
});

final adminUserSearchQueryProvider = StateProvider<String>((ref) => '');