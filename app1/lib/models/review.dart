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
    DateTime parseCreatedAt(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    int parseRating(dynamic value) {
      if (value is int) return value.clamp(1, 5);
      if (value is num) return value.round().clamp(1, 5);
      if (value is String) {
        final parsed = num.tryParse(value);
        if (parsed != null) return parsed.round().clamp(1, 5);
      }
      return 5;
    }

    return Review(
      id: id,
      tripId: map['tripId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      rating: parseRating(map['rating']),
      comment: map['comment'] ?? '',
      createdAt: parseCreatedAt(map['createdAt']),
      role: map['role']?.toString(),
    );
  }
}

