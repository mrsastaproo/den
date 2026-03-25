import 'dart:io';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;

  // Update display name
  Future<bool> updateDisplayName(String name) async {
    try {
      await _auth.currentUser?.updateDisplayName(name);
      await _auth.currentUser?.reload();
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({'displayName': name});
      }
      return true;
    } catch (e) {
      print('Update name error: $e');
      return false;
    }
  }

  // Upload profile photo to Firebase Storage
  Future<String?> uploadProfilePhoto(File imageFile) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      // 1. Upload to Firebase Storage
      final storageRef = _storage.ref().child('profiles').child('$uid.jpg');
      
      // Add metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': uid},
      );

      final uploadTask = await storageRef.putFile(imageFile, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // 2. Update Firebase Auth Profile
      await _auth.currentUser?.updatePhotoURL(downloadUrl);
      await _auth.currentUser?.reload();

      // 3. Sync with Firestore directly
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'photoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } catch (e) {
      print('Upload photo error: $e');
      rethrow;
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