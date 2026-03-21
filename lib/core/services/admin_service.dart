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
      photoUrl: d['photoUrl'] ?? '',
      isBanned: d['isBanned'] ?? false,
      banReason: d['banReason'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      lastActive: (d['lastActive'] as Timestamp?)?.toDate(),
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
      maintenanceMessage: d['maintenanceMessage'] ?? 'We\'re performing maintenance. Back soon!',
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
    // Count users
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

    await _db.collection('admin').doc('stats').set({
      'totalUsers': usersSnap.count ?? 0,
      'bannedUsers': bannedSnap.count ?? 0,
      'activeAnnouncements': annSnap.count ?? 0,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── USERS ──────────────────────────────────────────────────

  Stream<List<AdminUser>> getUsers({int limit = 50}) {
    _checkAdmin();
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(AdminUser.fromFirestore).toList());
  }

  Stream<List<AdminUser>> searchUsers(String query) {
    _checkAdmin();
    final q = query.trim().toLowerCase();
    return _db
        .collection('users')
        .orderBy('email')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(20)
        .snapshots()
        .map((snap) =>
            snap.docs.map(AdminUser.fromFirestore).toList());
  }

  Future<void> banUser(String uid, String reason) async {
    _checkAdmin();
    await _db.collection('users').doc(uid).set({
      'isBanned': true,
      'banReason': reason,
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': _auth.currentUser?.email,
    }, SetOptions(merge: true));
    await _db.collection('admin').doc('stats').update({
      'bannedUsers': FieldValue.increment(1),
    });
  }

  Future<void> unbanUser(String uid) async {
    _checkAdmin();
    await _db.collection('users').doc(uid).update({
      'isBanned': false,
      'banReason': '',
    });
    await _db.collection('admin').doc('stats').update({
      'bannedUsers': FieldValue.increment(-1),
    });
  }

  Future<void> deleteUserData(String uid) async {
    _checkAdmin();
    // Delete subcollections
    for (final sub in ['liked_songs', 'history', 'playlists']) {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection(sub)
          .limit(500)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) batch.delete(doc.reference);
      await batch.commit();
    }
    await _db.collection('users').doc(uid).delete();
  }

  Future<void> syncUserProfile(String uid, String email,
      String displayName, String photoUrl) async {
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

  // Active announcements for users (no admin guard)
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
  }

  Future<void> updateBanner(String id, Map<String, dynamic> data) async {
    _checkAdmin();
    await _db.collection('featured_banners').doc(id).update(data);
  }

  Future<void> deleteBanner(String id) async {
    _checkAdmin();
    await _db.collection('featured_banners').doc(id).delete();
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

  // Config for all users (no guard)
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
    required String style, // standard | wide | ranked
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
  }

  Future<void> updateCuratedSection(
      String id, Map<String, dynamic> data) async {
    _checkAdmin();
    await _db.collection('curated_sections').doc(id).update(data);
  }

  Future<void> deleteCuratedSection(String id) async {
    _checkAdmin();
    await _db.collection('curated_sections').doc(id).delete();
  }

  // ── ADMIN ACTIVITY LOG ─────────────────────────────────────

  Future<void> _logActivity(String action, Map<String, dynamic> details) async {
    await _db.collection('admin').doc('logs').collection('activity').add({
      'action': action,
      'details': details,
      'adminEmail': _auth.currentUser?.email,
      'timestamp': FieldValue.serverTimestamp(),
    });
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

final adminServiceProvider = Provider<AdminService>((ref) => AdminService());

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

final adminUserSearchQueryProvider = StateProvider<String>((ref) => '');