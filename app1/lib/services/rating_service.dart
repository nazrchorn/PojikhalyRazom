import 'package:cloud_firestore/cloud_firestore.dart';

class RatingService {
  RatingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> applyCancellationPenalty({
    required String userId,
    required double points,
    required String reason,
    String? tripId,
    String? bookingRequestId,
  }) async {
    if (userId.trim().isEmpty || points <= 0) {
      return;
    }

    final userRef = _firestore.collection('users').doc(userId);
    final eventRef = userRef.collection('rating_events').doc();

    await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        return;
      }

      final data = userSnap.data() ?? <String, dynamic>{};
      final current = (data['rating'] as num?)?.toDouble() ?? 5.0;
      final next = (current - points).clamp(1.0, 5.0).toDouble();

      tx.update(userRef, {
        'rating': next,
        'cancellationPenaltyCount': FieldValue.increment(1),
        'lastRatingPenaltyAt': FieldValue.serverTimestamp(),
      });

      tx.set(eventRef, {
        'type': 'cancellation_penalty',
        'reason': reason,
        'delta': -points,
        'tripId': tripId,
        'bookingRequestId': bookingRequestId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

