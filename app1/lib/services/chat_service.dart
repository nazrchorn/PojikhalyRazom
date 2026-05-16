import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    final userDoc = await _firestore.collection('users').doc(userId).get();
    return userDoc.data();
  }
}
