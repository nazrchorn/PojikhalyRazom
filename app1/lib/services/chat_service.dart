import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String systemChatUserId = 'poikhali_system';
  static const String systemChatName = 'Поїхали Разом';

  /// Потік кількості непрочитаних повідомлень користувача
  Stream<int> getUnreadMessagesCount(String uid) {
    return _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Отримати поток повідомлень для користувача
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessagesForUser(String uid) {
    return _firestore
        .collection('messages')
        .where(
          Filter.or(
            Filter('senderId', isEqualTo: uid),
            Filter('receiverId', isEqualTo: uid),
          ),
        )
        .snapshots();
  }

  /// Отримати поток повідомлень для конкретної розмови
  Stream<QuerySnapshot<Map<String, dynamic>>> getConversationMessages(
    String currentUserId,
    String partnerId,
  ) {
    return _firestore
        .collection('messages')
        .where('senderId', whereIn: [currentUserId, partnerId])
        .where('receiverId', whereIn: [currentUserId, partnerId])
        .snapshots();
  }

  /// Відправити повідомлення
  Future<void> sendMessage({
    required String currentUserId,
    required String receiverId,
    required String text,
    String tripId = '',
  }) async {
    await _firestore.collection('messages').add({
      'tripId': tripId,
      'senderId': currentUserId,
      'receiverId': receiverId,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> sendImageMessage({
    required String currentUserId,
    required String receiverId,
    required File imageFile,
    String text = '',
    String tripId = '',
  }) async {
    final extension = p.extension(imageFile.path).toLowerCase();
    final safeExt = extension.isEmpty ? '.jpg' : extension;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$currentUserId$safeExt';
    final ref = _storage.ref().child('chat_images').child(currentUserId).child(fileName);

    await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
    final imageUrl = await ref.getDownloadURL();

    await _firestore.collection('messages').add({
      'tripId': tripId,
      'senderId': currentUserId,
      'receiverId': receiverId,
      'text': text,
      'imageUrl': imageUrl,
      'sentAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> sendSystemMessage({
    required String receiverId,
    required String text,
    String tripId = '',
    String type = 'system',
    Map<String, dynamic>? metadata,
  }) async {
    await _firestore.collection('messages').add({
      'tripId': tripId,
      'senderId': systemChatUserId,
      'receiverId': receiverId,
      'text': text,
      'type': type,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      'sentAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'isSystem': true,
    });
  }

  /// Редагувати повідомлення
  Future<void> editMessage(String docId, String newText) async {
    await _firestore.collection('messages').doc(docId).update({
      'text': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Видалити повідомлення
  Future<void> deleteMessage(String docId) async {
    await _firestore.collection('messages').doc(docId).delete();
  }

  Future<void> setMessageReaction({
    required String docId,
    required String userId,
    required String emoji,
  }) async {
    await _firestore.collection('messages').doc(docId).set({
      'reactions': <String, dynamic>{userId: emoji},
    }, SetOptions(merge: true));
  }

  Future<void> clearMessageReaction({
    required String docId,
    required String userId,
  }) async {
    await _firestore.collection('messages').doc(docId).update({
      'reactions.$userId': FieldValue.delete(),
    });
  }

  /// Позначити вхідні повідомлення як прочитані
  Future<void> markIncomingAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String currentUserId,
  ) async {
    final updates = docs.where((doc) {
      final data = doc.data();
      final receiverId = data['receiverId'] as String? ?? '';
      final isRead = data['isRead'] as bool? ?? false;
      return receiverId == currentUserId && !isRead;
    }).toList();

    if (updates.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in updates) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Завантажити інформацію про користувача для чату
  Future<Map<String, dynamic>?> loadUserSummary(String userId) async {
    if (userId == systemChatUserId) {
      return <String, dynamic>{
        'name': systemChatName,
        'photoUrl': null,
      };
    }
    final userDoc = await _firestore.collection('users').doc(userId).get();
    return userDoc.data();
  }
}
