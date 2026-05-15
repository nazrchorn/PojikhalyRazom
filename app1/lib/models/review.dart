import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String tripId;
  final String fromUserId; // хто написав відгук
  final String toUserId; // кому написав
  final int rating; // 1-5 зірочок
  final String comment;
  final DateTime createdAt;
  final String? role; // 'driver' або 'passenger'

  Review({
    required this.id,
    required this.tripId,
    required this.fromUserId,
    required this.toUserId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt,
      'role': role,
    };
  }

  factory Review.fromMap(Map<String, dynamic> map, String id) {
    return Review(
      id: id,
      tripId: map['tripId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      rating: map['rating'] ?? 5,
      comment: map['comment'] ?? '',
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      role: map['role'],
    );
  }
}

