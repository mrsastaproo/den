import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import 'auth_service.dart';

class Message {
  final String id;
  final String senderId;
  final String content;
  final String type; // 'text', 'song', 'playlist'
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    this.metadata,
    required this.createdAt,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      content: data['content'] ?? '',
      type: data['type'] ?? 'text',
      metadata: data['metadata'] as Map<String, dynamic>?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'content': content,
      'type': type,
      if (metadata != null) 'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? userId;

  ChatService(this.userId);

  /// Helper to generate a deterministic chatId for 2 users to share
  String _getChatId(String otherUid) {
    if (userId == null) return '';
    final list = [userId!, otherUid]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Ensures a chat document is created with members indexing active
  Future<String> getOrCreateChat(String otherUid) async {
    if (userId == null) return '';
    final chatId = _getChatId(otherUid);
    final ref = _db.collection('chats').doc(chatId);

    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'members': [userId, otherUid],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return chatId;
  }

  /// Sends a general or itemized message cell payload
  Future<void> sendMessage(String otherUid, String content, {String type = 'text', Map<String, dynamic>? metadata}) async {
    if (userId == null) return;
    
    final chatId = await getOrCreateChat(otherUid);
    final chatRef = _db.collection('chats').doc(chatId);

    final message = Message(
      id: '', // filled by Firestore
      senderId: userId!,
      content: content,
      type: type,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();
    
    // Add to messages sub-collection
    batch.set(chatRef.collection('messages').doc(), message.toJson());
    
    // Update main chat node timestamp
    batch.update(chatRef, {'updatedAt': FieldValue.serverTimestamp()});

    await batch.commit();
  }

  /// Share a song to a friend
  Future<void> shareSong(String otherUid, Song song) async {
    await sendMessage(
      otherUid,
      'Shared a song: ${song.title}',
      type: 'song',
      metadata: song.toJson(),
    );
  }

  /// Listen for message streams in real-time
  Stream<List<Message>> listenMessages(String otherUid) {
    if (userId == null) return Stream.value([]);
    final chatId = _getChatId(otherUid);
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Message.fromFirestore(d)).toList());
  }
}

// ─── PROVIDERS ────────────────────────────────────────────────

final chatServiceProvider = Provider<ChatService>((ref) {
  final user = ref.watch(authStateProvider).value;
  return ChatService(user?.uid);
});

final chatMessagesProvider = StreamProvider.family<List<Message>, String>((ref, otherUid) {
  return ref.watch(chatServiceProvider).listenMessages(otherUid);
});
