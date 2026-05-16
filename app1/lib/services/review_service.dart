import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Отримати поток всіх відгуків для користувача
  Stream<QuerySnapshot<Map<String, dynamic>>> getReviewsForUser(String userId) {
    return _firestore
        .collection('reviews')
        .where('toUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Завантажити всі відгуки для користувача (Future)
  Future<List<Review>> loadReviewsForUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('toUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromMap(doc.data(), doc.id))
          .toList();
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
}

