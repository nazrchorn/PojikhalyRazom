import 'package:cloud_firestore/cloud_firestore.dart';
class Message {
  final String id;
  final String tripId;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime sentAt;

  Message({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.sentAt,
  });

  factory Message.fromMap(String id, Map<String, dynamic> map) {
    return Message(
      id: id,
      tripId: map['tripId'],
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      text: map['text'],
      sentAt: (map['sentAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'sentAt': sentAt,
    };
  }
}