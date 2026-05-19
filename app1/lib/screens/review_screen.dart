import 'package:flutter/material.dart';
import '../services/review_service.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';

class ReviewScreen extends StatefulWidget {
  final String tripId;
  final String fromUserId;
  final String toUserId;
  final String toUserName;
  final String? toUserPhotoUrl;
  final String role; // 'driver' або 'passenger'

  const ReviewScreen({
    super.key,
    required this.tripId,
    required this.fromUserId,
    required this.toUserId,
    required this.toUserName,
    this.toUserPhotoUrl,
    required this.role,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int rating = 5;
  late TextEditingController commentController;
  bool isLoading = false;
  final ReviewService _reviewService = ReviewService();
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();

  final Color primaryTurquoise = const Color(0xFF1F6F66);
  final Color bgTurquoiseLight = const Color(0xFFE8F8F5);

  @override
  void initState() {
    super.initState();
    commentController = TextEditingController();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Напишіть коментар')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final fromUserData = await _userService.loadUserData(widget.fromUserId);
      await _reviewService.submitReview(
        tripId: widget.tripId,
        fromUserId: widget.fromUserId,
        toUserId: widget.toUserId,
        rating: rating,
        comment: commentController.text.trim(),
        role: widget.role,
      );

      await _reviewService.recalculateAndStoreUserRating(widget.toUserId);

      final fromUserName = fromUserData?['name'] as String? ?? 'Користувач';
      await _chatService.sendSystemMessage(
        receiverId: widget.toUserId,
        tripId: widget.tripId,
        type: 'review_received',
        text: '$fromUserName залишив(ла) вам відгук після поїздки: $rating/5 ⭐',
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Відгук надіслано до ${widget.toUserName}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Написати відгук'),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Theme.of(context).appBarTheme.surfaceTintColor,
        elevation: 0,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- Аватар і ім'я користувача ---
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: bgTurquoiseLight,
                    backgroundImage: (widget.toUserPhotoUrl != null &&
                            widget.toUserPhotoUrl!.isNotEmpty)
                        ? NetworkImage(widget.toUserPhotoUrl!)
                        : null,
                    child: (widget.toUserPhotoUrl == null ||
                            widget.toUserPhotoUrl!.isEmpty)
                        ? Icon(Icons.person, size: 50, color: primaryTurquoise)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.toUserName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.role == 'driver' ? 'Водій (Пасажир)' : 'Пасажир',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- Оцінка зірочками ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Оцініть поїздку',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () => setState(() => rating = index + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: primaryTurquoise,
                              size: 44,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _getRatingText(rating),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // --- Текстове поле для коментара ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ваш коментар',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Розповідіть про вашу поїздку...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primaryTurquoise, width: 2),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // --- Кнопка надіслати ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTurquoise,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Надіслати відгук',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // --- Кнопка пропустити ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: primaryTurquoise),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Пропустити',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryTurquoise,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Дуже погано';
      case 2:
        return 'Погано';
      case 3:
        return 'Задовільно';
      case 4:
        return 'Добре';
      case 5:
        return 'Чудово!';
      default:
        return '';
    }
  }
}

