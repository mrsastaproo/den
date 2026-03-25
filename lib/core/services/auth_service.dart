import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth    _auth         = FirebaseAuth.instance;
  final GoogleSignIn    _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db         = FirebaseFirestore.instance;

  Stream<User?> get userStream => _auth.authStateChanges();
  User? get currentUser        => _auth.currentUser;
  bool  get isLoggedIn         => _auth.currentUser != null;

  // ── Google Sign In ────────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      await _ensureUserDoc(result.user);
      return result;
    } catch (e) {
      print('Google sign in error: $e');
      return null;
    }
  }

  // ── Email sign up ─────────────────────────────────────────────
  Future<UserCredential?> signUpWithEmail(
      String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await _ensureUserDoc(result.user);
      return result;
    } catch (e) {
      print('Sign up error: $e');
      return null;
    }
  }

  // ── Email sign in ─────────────────────────────────────────────
  Future<UserCredential?> signInWithEmail(
      String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      await _ensureUserDoc(result.user);
      return result;
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  // ── Password reset ────────────────────────────────────────────
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print('Password reset error: $e');
      return false;
    }
  }

  // ── Sign out ──────────────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Delete account ────────────────────────────────────────────
  /// Wipes all Firestore data for the user, then deletes the
  /// Firebase Auth account. Called from settings_screen.dart.
  /// If the session is too old Firebase will throw
  /// [requires-recent-login] — the caller should catch this and
  /// prompt the user to re-authenticate before retrying.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // 1. Delete all Firestore collections owned by this user
    await Future.wait([
      _deleteCollection('users/$uid/history'),
      _deleteCollection('users/$uid/liked_songs'),
      _deleteCollection('users/$uid/playlists'),
      _deleteCollection('users/$uid/followed_artists'),
      _deleteCollection('users/$uid/saved_albums'),
    ]);

    // 2. Delete top-level user documents
    await Future.wait([
      _db.doc('users/$uid').delete().catchError((_) {}),
      _db.doc('user_settings/$uid').delete().catchError((_) {}),
    ]);

    // 3. Delete Firebase Storage profile photo
    try {
      // If you store photos at profile_photos/{uid}.jpg uncomment:
      // await FirebaseStorage.instance
      //     .ref('profile_photos/$uid.jpg')
      //     .delete();
    } catch (_) {}

    // 4. Delete the Firebase Auth account itself (must be last)
    await user.delete();
  }

  Future<void> updateLastActive() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Doc might not exist yet, ensureUserDoc will handle it
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  /// Creates a minimal user document on first sign-in so that
  /// Firestore queries never have to deal with a missing doc.
  Future<void> _ensureUserDoc(User? user) async {
    if (user == null) return;
    final ref = _db.doc('users/${user.uid}');
    final snap = await ref.get();
    
    final data = {
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'lastActive': FieldValue.serverTimestamp(),
      'isOnline': true,
    };

    if (!snap.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['plan'] = 'free';
      data['photoUrl'] = user.photoURL ?? '';
      data['photoURL'] = user.photoURL ?? '';
      await ref.set(data);
    } else {
      await ref.update(data);
    }
  }

  Future<void> setUserStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).update({
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Batch-deletes all documents in a sub-collection.
  /// Firestore does not cascade-delete sub-collections automatically.
  Future<void> _deleteCollection(String path) async {
    try {
      const batchSize = 100;
      var query = _db.collection(path).limit(batchSize);
      while (true) {
        final snap = await query.get();
        if (snap.docs.isEmpty) break;
        final batch = _db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snap.docs.length < batchSize) break;
      }
    } catch (_) {}
  }
}

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).userStream;
});