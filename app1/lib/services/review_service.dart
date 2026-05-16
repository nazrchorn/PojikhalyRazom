import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Отримати поток всіх відгуків для користувача
  Stream<QuerySnapshot<Map<String, dynamic>>> getReviewsForUser(String userId) {
    return _firestore
        .collection('reviews')
        .where('toUserId', isEqualTo: userId)
        .snapshots();
  }

  /// Завантажити всі відгуки для користувача (Future)
  Future<List<Review>> loadReviewsForUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('toUserId', isEqualTo: userId)
          .get();

      final reviews = snapshot.docs
          .map((doc) => Review.fromMap(doc.data(), doc.id))
          .toList();
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    } catch (e) {
      rethrow;
    }
  }

  /// Додати новий відгук
  Future<void> addReview(Review review) async {
    try {
      await _firestore.collection('reviews').add(review.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> submitReview({
    required String tripId,
    required String fromUserId,
    required String toUserId,
    required int rating,
    required String comment,
    required String role,
  }) async {
    await _firestore.collection('reviews').add({
      'tripId': tripId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'rating': rating,
      'comment': comment,
      'createdAt': DateTime.now(),
      'role': role,
    });
  }

  /// Обчислити середню оцінку для користувача
  Future<double> getAverageRating(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('toUserId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      final reviews = snapshot.docs
          .map((doc) => Review.fromMap(doc.data(), doc.id))
          .toList();

      final sum = reviews.fold<double>(0, (sum, r) => sum + r.rating);
      return sum / reviews.length;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getReviewCountForUser(String userId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('toUserId', isEqualTo: userId)
        .get();
    return snapshot.docs.length;
  }

  /// Отримати відгуки за конкретною поїздкою
  Stream<QuerySnapshot<Map<String, dynamic>>> getReviewsForTrip(String tripId) {
    return _firestore
        .collection('reviews')
        .where('tripId', isEqualTo: tripId)
        .snapshots();
  }

  /// Перевірити, чи користувач вже залишив відгук для конкретної поїздки
  Future<bool> hasUserReviewedTrip(String userId, String tripId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('fromUserId', isEqualTo: userId)
          .where('tripId', isEqualTo: tripId)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> hasUserReviewedTripForTarget({
    required String fromUserId,
    required String toUserId,
    required String tripId,
  }) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('tripId', isEqualTo: tripId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> recalculateAndStoreUserRating(String userId) async {
    final reviewsSnapshot = await _firestore
        .collection('reviews')
        .where('toUserId', isEqualTo: userId)
        .get();

    if (reviewsSnapshot.docs.isEmpty) {
      await _firestore.collection('users').doc(userId).update({
        'rating': 0.0,
        'reviewCount': 0,
      });
      return;
    }

    final reviews = reviewsSnapshot.docs
        .map((doc) => Review.fromMap(doc.data(), doc.id))
        .toList();
    final sum = reviews.fold<double>(0, (acc, review) => acc + review.rating);
    final average = sum / reviews.length;

    await _firestore.collection('users').doc(userId).update({
      'rating': average,
      'reviewCount': reviews.length,
    });
  }
}

