import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';
import '../services/review_service.dart';

class ReviewsListScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const ReviewsListScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  final Color primaryTurquoise = const Color(0xFF2F8F7F);
  final Color bgTurquoiseLight = const Color(0xFFE8F8F5);
  final Color accentTurquoiseDark = const Color(0xFF2F8F7F);
  final Color mintBackground = const Color(0xFFF6FCFA);
  final Color mintAppBar = const Color(0xFFF4FBF9);

  @override
  Widget build(BuildContext context) {
    final reviewService = ReviewService();

    return Scaffold(
      backgroundColor: mintBackground,
      appBar: AppBar(
        title: const Text('Відгуки'),
        centerTitle: true,
        backgroundColor: mintAppBar,
        surfaceTintColor: mintAppBar,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: reviewService.getReviewsForUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      'Не вдалося завантажити відгуки',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Спробуйте відкрити екран ще раз.',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.comment_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Відгуків ще немає',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final reviews = snapshot.data!.docs
              .map((doc) => Review.fromMap(doc.data(), doc.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // Розраховуємо середню оцінку
          final averageRating = reviews.isEmpty
              ? 0.0
              : reviews.fold<double>(0, (sum, r) => sum + r.rating) / reviews.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Статистика ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (index) => Icon(
                                  index < averageRating.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: accentTurquoiseDark,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${reviews.length}\nвідгуків',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // --- Список відгуків ---
                const Text(
                  'Останні відгуки',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                ...reviews.map((review) => _buildReviewCard(context, review)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Заголовок з зірочками ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating ? Icons.star : Icons.star_border,
                    color: accentTurquoiseDark,
                    size: 18,
                  ),
                ),
              ),
              Text(
                _formatDate(review.createdAt),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // --- Коментар ---
          Text(
            review.comment,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),

          if (review.role != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: bgTurquoiseLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                review.role == 'driver' ? '🚗 Від водія' : '👤 Від пасажира',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentTurquoiseDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Сьогодні';
    } else if (difference.inDays == 1) {
      return 'Вчора';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} днів тому';
    } else if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      return '$weeks ${weeks == 1 ? 'тиждень' : 'тижднів'} тому';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}

