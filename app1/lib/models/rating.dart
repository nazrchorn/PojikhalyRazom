import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String id;
  final String tripId;
  final String reviewerId;
  final String reviewedUserId;
  final int score;
  final String comment;
  final DateTime createdAt;

  Rating({
    required this.id,
    required this.tripId,
    required this.reviewerId,
    required this.reviewedUserId,
    required this.score,
    required this.comment,
    required this.createdAt,
  });

  factory Rating.fromMap(String id, Map<String, dynamic> map) {
    return Rating(
      id: id,
      tripId: map['tripId'],
      reviewerId: map['reviewerId'],
      reviewedUserId: map['reviewedUserId'],
      score: map['score'],
      comment: map['comment'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'reviewerId': reviewerId,
      'reviewedUserId': reviewedUserId,
      'score': score,
      'comment': comment,
      'createdAt': createdAt,
    };
  }
}