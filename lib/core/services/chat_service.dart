import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

class Message {
  final String id;
  final String senderId;
  final String content;
  final String type; // 'text', 'song', 'playlist'
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final List<String> readBy; // List of UIDs who read the message

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    this.metadata,
    required this.createdAt,
    this.readBy = const [],
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
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'content': content,
      'type': type,
      if (metadata != null) 'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [senderId], // Sender has read their own message
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
    
    // Update main chat node with last message info for notifications
    batch.update(chatRef, {
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': content,
      'lastSenderId': userId!,
    });

    await batch.commit();
  }

  /// Share any media (song, playlist, album, artist) to a friend
  Future<void> shareMedia(String otherUid, String type, Map<String, dynamic> metadata) async {
    final title = metadata['title'] ?? metadata['name'] ?? 'media';
    await sendMessage(
      otherUid,
      'Shared a $type: $title',
      type: type,
      metadata: metadata,
    );
  }

  /// Delete all messages in a chat between two users
  Future<void> clearChat(String otherUid) async {
    if (userId == null) return;
    final chatId = _getChatId(otherUid);
    final msgs = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .limit(500)
        .get();
    final batch = _db.batch();
    for (final d in msgs.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
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

  // ─── TYPING INDICATORS ─────────────────────────────────────

  Future<void> setTypingStatus(String otherUid, bool isTyping) async {
    if (userId == null) return;
    final chatId = _getChatId(otherUid);
    await _db.collection('chats').doc(chatId).update({
      'typing.$userId': isTyping,
    });
  }

  Stream<bool> listenTypingStatus(String otherUid) {
    if (userId == null) return Stream.value(false);
    final chatId = _getChatId(otherUid);
    return _db.collection('chats').doc(chatId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null || data['typing'] == null) return false;
      return (data['typing'] as Map<String, dynamic>)[otherUid] == true;
    });
  }

  // ─── READ RECEIPTS ──────────────────────────────────────────

  Future<void> markAsRead(String otherUid) async {
    if (userId == null) return;
    final chatId = _getChatId(otherUid);
    final messages = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isEqualTo: otherUid)
        .get();

    final batch = _db.batch();
    for (var doc in messages.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      if (!readBy.contains(userId)) {
        readBy.add(userId!);
        batch.update(doc.reference, {'readBy': readBy});
      }
    }
    await batch.commit();
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

final typingStatusProvider = StreamProvider.family<bool, String>((ref, otherUid) {
  return ref.watch(chatServiceProvider).listenTypingStatus(otherUid);
});

class ChatSummary {
  final String chatId;
  final String lastMessage;
  final String lastSenderId;
  final DateTime updatedAt;

  ChatSummary({
    required this.chatId,
    required this.lastMessage,
    required this.lastSenderId,
    required this.updatedAt,
  });
}

final chatsSummaryProvider = StreamProvider<List<ChatSummary>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('chats')
      .where('members', arrayContains: user.uid)
      .snapshots()
      .map((snap) => snap.docs.map((d) {
            final data = d.data();
            return ChatSummary(
              chatId: d.id,
              lastMessage: data['lastMessage'] ?? '',
              lastSenderId: data['lastSenderId'] ?? '',
              updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList());
});
