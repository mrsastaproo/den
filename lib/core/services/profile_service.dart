import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;

  // Update display name
  Future<bool> updateDisplayName(String name) async {
    try {
      await _auth.currentUser?.updateDisplayName(name);
      await _auth.currentUser?.reload();
      return true;
    } catch (e) {
      print('Update name error: $e');
      return false;
    }
  }

  // Upload profile photo
  Future<String?> uploadProfilePhoto(File imageFile) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      final ref = _storage.ref()
        .child('profile_photos')
        .child('$uid.jpg');

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update Firebase Auth profile
      await _auth.currentUser?.updatePhotoURL(downloadUrl);
      await _auth.currentUser?.reload();

      return downloadUrl;
    } catch (e) {
      print('Upload photo error: $e');
      return null;
    }
  }

  // Update email
  Future<bool> updateEmail(String email) async {
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(email);
      return true;
    } catch (e) {
      print('Update email error: $e');
      return false;
    }
  }

  // Delete account
  Future<bool> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
      return true;
    } catch (e) {
      print('Delete account error: $e');
      return false;
    }
  }
}

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService());