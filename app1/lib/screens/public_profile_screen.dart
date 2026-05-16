import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user.dart' as app_user;
import '../models/car.dart';
import 'avatar_crop_screen.dart';
import '../services/user_service.dart';
import '../services/review_service.dart';
import '../services/trip_service.dart';
import 'edit_profile_screen.dart';
import 'add_car_dialog.dart';
import 'login_screen.dart';
import 'registration_screen.dart';
import 'reviews_list_screen.dart';
import 'messanger_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final bool isMyProfile;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.isMyProfile = false,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  app_user.User? currentUser;
  bool isLoading = true;
  final UserService _userService = UserService();
  final ReviewService _reviewService = ReviewService();
  final TripService _tripService = TripService();

  // Твої фірмові кольори
  final Color primaryTurquoise = const Color(0xFF2F8F7F);
  final Color bgTurquoiseLight = const Color(0xFFE8F8F5);
  final Color accentTurquoiseDark = const Color(0xFF2F8F7F);
  final Color accentTurquoiseDeep = const Color(0xFF1F6F66);
  final Color accentTurquoiseSoft = const Color(0xFFD9F3EE);
  final Color accentTurquoiseSurface = const Color(0xFFF2FBF8);
  final Color pageMintBackground = const Color(0xFFF6FCFA);
  final Color appBarMintBackground = const Color(0xFFF4FBF9);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (widget.userId.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    try {
      final loadedUser = await _userService.loadUser(widget.userId);

      if (mounted) {
        if (loadedUser != null) {
          setState(() {
            currentUser = loadedUser;
            isLoading = false;
          });
        } else {
          // ЯКЩО ДОКУМЕНТА НЕМАЄ (новий телефон/акаунт)
          setState(() {
            isLoading = false;
            currentUser = null;
          });

          // Для вкладки профілю в main-navigation лишаємося в поточному shell.
        }
      }
    } catch (e) {
      debugPrint("Помилка завантаження: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => screen),
          (route) => false,
    );
  }
  // Логіка завантаження фото
  Future<void> _pickAndUploadPhoto() async {
    if (!widget.isMyProfile) return;

    try {
      final picker = ImagePicker();
      final navigator = Navigator.of(context);
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
        requestFullMetadata: false,
      );

      if (pickedFile == null) {
        return;
      }

      final file = await navigator.push<File?>(
        MaterialPageRoute(
          builder: (_) => AvatarCropScreen(imageFile: File(pickedFile.path), accentColor: primaryTurquoise),
        ),
      );

      if (file == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Кадрування скасовано')),
        );
        return;
      }
      
      // Перевіряємо розмір файлу
      final fileSize = file.lengthSync();
      if (fileSize > 5 * 1024 * 1024) { // 5MB максимум
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл занадто великий (максимум 5MB)')),
        );
        return;
      }

      final url = await _userService.uploadProfilePhoto(userId: widget.userId, file: file);
      await _userService.updatePhotoUrl(widget.userId, url);

      if (!mounted) {
        return;
      }

      _loadUserData(); // Перезавантажуємо дані, щоб оновити UI
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Фото успішно завантажено!')),
        );
      }
    } catch (e) {
      debugPrint("Помилка завантаження фото: $e");
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Помилка завантаження фото: ${e.toString()}")),
      );
    }
  }

  // Логіка додавання нового автомобіля
  Future<void> _addNewCar() async {
    final newCar = await showDialog<Car>(
      context: context,
      builder: (context) => const AddCarDialog(),
    );

    if (newCar != null && mounted) {
      try {
        await _userService.addCar(widget.userId, newCar);

        _loadUserData(); // Перезавантажуємо дані, щоб оновити UI
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Автомобіль успішно додан!"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint("Помилка збереження автомобіля: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ Помилка збереження автомобіля"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }
  Future<void> _deleteCar(Car car) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Видалити авто?"),
        content: Text("Ви впевнені, що хочете видалити ${car.brand} ${car.model}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Скасувати")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Видалити", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _userService.deleteCar(widget.userId, car);
      _loadUserData(); // Оновлюємо UI після видалення
    }
  }
  Future<Map<String, dynamic>> _loadProfileStats() async {
    final averageRating = await _reviewService.getAverageRating(widget.userId);
    final reviewCount = await _reviewService.getReviewCountForUser(widget.userId);
    final completedTrips = await _tripService.getCompletedTripsCountForDriver(widget.userId);

    return <String, dynamic>{
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'completedTrips': completedTrips,
    };
  }

  void _openChatWithUser(app_user.User user) {
    final currentUserId = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty || currentUserId == user.id) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          currentUserId: currentUserId,
          partnerId: user.id,
          partnerName: user.name,
          partnerPhotoUrl: user.photoUrl,
        ),
      ),
    );
  }

  Future<void> _callUser(String rawPhone) async {
    final normalized = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Номер телефону недоступний')),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Подзвонити?'),
        content: Text('Зателефонувати на номер $normalized'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryTurquoise),
            child: const Text('Подзвонити', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final uri = Uri(scheme: 'tel', path: normalized);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося відкрити дзвінок')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: primaryTurquoise)));
    }
    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle_outlined, size: 100, color: accentTurquoiseDeep.withValues(alpha: 0.55)),
              const SizedBox(height: 20),
              const Text("Ви ще не зареєстровані", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Увійдіть у наявний акаунт або створіть новий профіль для поїздок",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              // КНОПКА ВХОДУ (Заповнена)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primaryTurquoise, accentTurquoiseDark]),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ElevatedButton(
                    onPressed: () => _navigateTo(const LoginScreen()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("Увійти", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // КНОПКА РЕЄСТРАЦІЇ (Контурна)
              OutlinedButton(
                onPressed: () => _navigateTo(const RegistrationScreen()),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accentTurquoiseDeep, width: 2),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  foregroundColor: accentTurquoiseDeep,
                ),
                child: Text("Створити акаунт", style: TextStyle(color: accentTurquoiseDeep, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
    final user = currentUser!;

    return Scaffold(
      backgroundColor: pageMintBackground,
      appBar: AppBar(
        title: Text(widget.isMyProfile ? "Мій профіль" : "Профіль",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: appBarMintBackground,
        surfaceTintColor: appBarMintBackground,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [appBarMintBackground, accentTurquoiseSoft.withValues(alpha: 0.6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          if (widget.isMyProfile)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) async {
                if (value == "edit") {
                  final updatedUser = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EditProfileScreen(user: user)),
                  );
                  if (!context.mounted) return;
                  if (updatedUser != null) _loadUserData();
                } else if (value == "logout") {
                  await fb_auth.FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: "edit", child: Row(children: [Icon(Icons.edit, size: 18, color: accentTurquoiseDeep), const SizedBox(width: 8), const Text("Редагувати")])),
                const PopupMenuItem(value: "logout", child: Row(children: [Icon(Icons.logout, size: 18, color: Colors.red), SizedBox(width: 8), Text("Вийти", style: TextStyle(color: Colors.red))])),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- Аватар ---
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: bgTurquoiseLight,
                          backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                              ? NetworkImage(user.photoUrl!) : null,
                          child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                              ? Icon(Icons.person, size: 60, color: accentTurquoiseDark)
                              : null,
                        ),
                        if (widget.isMyProfile)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: accentTurquoiseDeep,
                              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: accentTurquoiseSoft.withValues(alpha: 0.9), blurRadius: 6, offset: const Offset(0, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "${user.getAge() ?? '—'} років • ${user.phone}",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                   if (!widget.isMyProfile &&
                       (fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '').isNotEmpty &&
                       (fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '') != user.id) ...[
                     const SizedBox(height: 12),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         _buildQuickActionButton(
                           icon: Icons.chat_bubble_outline_rounded,
                           label: 'Чат',
                           onTap: () => _openChatWithUser(user),
                         ),
                         const SizedBox(width: 10),
                         _buildQuickActionButton(
                           icon: Icons.call_rounded,
                           label: 'Подзвонити',
                           onTap: () => _callUser(user.phone),
                         ),
                       ],
                     ),
                   ],
                   const SizedBox(height: 10),
                   FutureBuilder<Map<String, dynamic>>(
                     future: _loadProfileStats(),
                     builder: (context, statsSnapshot) {
                       final stats = statsSnapshot.data ?? const <String, dynamic>{};
                       final double averageRating = (stats['averageRating'] as num?)?.toDouble() ?? user.rating;
                       final int reviewCount = (stats['reviewCount'] as num?)?.toInt() ?? 0;
                       final int completedTrips = (stats['completedTrips'] as num?)?.toInt() ?? user.tripsCompleted;

                       return Wrap(
                         alignment: WrapAlignment.center,
                         spacing: 12,
                         runSpacing: 12,
                         children: [
                           _buildStatChip(
                             icon: Icons.star_rounded,
                              iconColor: accentTurquoiseDeep,
                             title: averageRating.toStringAsFixed(1),
                             subtitle: 'середній рейтинг',
                               iconBackground: Colors.white,
                              backgroundColor: accentTurquoiseSurface,
                              borderColor: accentTurquoiseSoft,
                           ),
                           _buildStatChip(
                             icon: Icons.directions_car_filled_rounded,
                              iconColor: accentTurquoiseDark,
                             title: '$completedTrips',
                             subtitle: 'виконаних поїздок',
                               iconBackground: Colors.white,
                               backgroundColor: accentTurquoiseSurface,
                               borderColor: accentTurquoiseSoft,
                           ),
                           _buildStatChip(
                             icon: Icons.rate_review_rounded,
                              iconColor: accentTurquoiseDark,
                             title: '$reviewCount',
                             subtitle: 'відгуків',
                               iconBackground: Colors.white,
                              backgroundColor: accentTurquoiseSurface,
                              borderColor: accentTurquoiseSoft,
                           ),
                         ],
                       );
                     },
                   ),
                ],
              ),
            ),

            const SizedBox(height: 25),
            _buildSectionTitle("Про користувача"),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildHabitRow(Icons.wc_rounded, user.gender.isNotEmpty ? user.gender : "Стать не вказана"),
              const Divider(height: 24),
              _buildHabitRow(
                user.isTalkative ? Icons.chat_rounded : Icons.speaker_notes_off_rounded,
                user.isTalkative ? "Любить побалакати" : "Мовчазний у дорозі",
              ),
              const Divider(height: 24),
              _buildHabitRow(
                user.isSmoker ? Icons.smoking_rooms_rounded : Icons.smoke_free_rounded,
                user.isSmoker ? "Палить" : "Не палить",
              ),
            ]),

            const SizedBox(height: 25),
            const SizedBox(height: 25),
            _buildSectionTitle("Транспорт"),
            const SizedBox(height: 12),

            // Перевіряємо, чи є автомобілі в масиві
            if (user.cars.isNotEmpty) ...[
              // Проходимо по кожному автомобілю в списку
              ...user.cars.map((car) => Padding(
                padding: const EdgeInsets.only(bottom: 12), // Відступ між картками
                child: _buildCarCard(car),
              )),

              // Якщо це мій профіль, показуємо кнопку "Додати ще" під списком
              if (widget.isMyProfile) _buildAddCarButton(),
            ] else if (widget.isMyProfile) ...[
              // Якщо машин немає зовсім, показуємо тільки кнопку додавання
              _buildAddCarButton(),
            ] else ...[
              // Якщо це чужий профіль і машин немає
              const Text("Автомобілі не вказані", style: TextStyle(color: Colors.grey)),
            ],

            const SizedBox(height: 30),
            _buildReviewsPreview(user),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: accentTurquoiseDeep,
          shadows: [Shadow(color: accentTurquoiseSoft.withValues(alpha: 0.8), blurRadius: 4, offset: const Offset(0, 1))],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]),
      child: Column(children: children),
    );
  }

  Widget _buildCarCard(Car car) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: accentTurquoiseSoft, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.directions_car_filled_rounded, color: accentTurquoiseDark),
        ),
        title: Text("${car.brand} ${car.model}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${car.color ?? '—'} • ${car.year} рік"),
        trailing: widget.isMyProfile
            ? IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: accentTurquoiseDark.withValues(alpha: 0.65)),
          onPressed: () => _deleteCar(car),
        )
            : null,
      ),
    );
  }

  Widget _buildHabitRow(IconData icon, String text) {
    return Row(children: [Icon(icon, color: accentTurquoiseDark, size: 22), const SizedBox(width: 15), Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))]);
  }

  Widget _buildAddCarButton() {
    return GestureDetector(
      onTap: _addNewCar,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [accentTurquoiseSurface, accentTurquoiseSoft]),
          border: Border.all(color: accentTurquoiseDark.withValues(alpha: 0.45), width: 1.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: accentTurquoiseDark, size: 22),
            const SizedBox(width: 10),
            Text(
              "Додати автомобіль",
              style: TextStyle(
                color: accentTurquoiseDark,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color iconBackground,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryTurquoise, accentTurquoiseDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: accentTurquoiseDark.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsPreview(app_user.User user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewsListScreen(userId: widget.userId, userName: user.name),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
        ),
        child: StreamBuilder<dynamic>(
          stream: _reviewService.getReviewsForUser(widget.userId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewsHeader(),
                  const SizedBox(height: 12),
                  Text('Не вдалося завантажити відгуки', style: TextStyle(color: Colors.red.shade300, fontSize: 14)),
                ],
              );
            }

            final docs = snapshot.data?.docs as List<dynamic>? ?? <dynamic>[];
            final sortedDocs = [...docs]..sort((a, b) {
              final aDate = (a.data()['createdAt'] as dynamic)?.toDate?.call() ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate = (b.data()['createdAt'] as dynamic)?.toDate?.call() ?? DateTime.fromMillisecondsSinceEpoch(0);
              return (bDate as DateTime).compareTo(aDate as DateTime);
            });

            if (sortedDocs.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewsHeader(),
                  const SizedBox(height: 12),
                  const Text('Відгуки поки що відсутні', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              );
            }

            final top = sortedDocs.take(3).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewsHeader(),
                const SizedBox(height: 12),
                ...top.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final int r = (data['rating'] as num?)?.toInt() ?? 5;
                  final String comment = (data['comment'] as String?)?.trim().isNotEmpty == true
                      ? data['comment'] as String
                      : 'Без коментаря';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('⭐' * r + '  $comment', maxLines: 2, overflow: TextOverflow.ellipsis),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReviewsHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentTurquoiseSoft, bgTurquoiseLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.rate_review_rounded, color: accentTurquoiseDeep, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Відгуки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Переглянути, що кажуть інші', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: accentTurquoiseDark.withValues(alpha: 0.75)),
      ],
    );
  }
}