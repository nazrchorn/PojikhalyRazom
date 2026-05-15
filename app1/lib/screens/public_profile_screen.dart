import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart' as app_user;
import '../models/car.dart';
import 'edit_profile_screen.dart';
import 'add_car_dialog.dart';
import 'login_screen.dart';
import 'registration_screen.dart';
import 'reviews_list_screen.dart';

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

  // Твої фірмові кольори
  final Color primaryTurquoise = const Color(0xFF5DD9C1);
  final Color bgTurquoiseLight = const Color(0xFFE8F8F5);

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
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();

      if (mounted) {
        if (doc.exists) {
          setState(() {
            currentUser = app_user.User.fromMap(doc.id, doc.data() as Map<String, dynamic>);
            isLoading = false;
          });
        } else {
          // ЯКЩО ДОКУМЕНТА НЕМАЄ (новий телефон/акаунт)
          setState(() {
            isLoading = false;
            currentUser = null;
          });

          // Якщо це мав бути "Мій профіль", але даних немає - виходимо на логін
          if (widget.isMyProfile) {
            _showAuthRedirectDialog();
          }
        }
      }
    } catch (e) {
      debugPrint("Помилка завантаження: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

// Допоміжний метод для редіректу
  void _showAuthRedirectDialog() {
    Future.delayed(Duration.zero, () {
      if (mounted) {
        fbAuth.FirebaseAuth.instance.signOut(); // На всякий випадок скидаємо сесію
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
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
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final ref = FirebaseStorage.instance
            .ref()
            .child("profile_photos/${widget.userId}/avatar.jpg");

        await ref.putFile(file);
        final url = await ref.getDownloadURL();

        await FirebaseFirestore.instance.collection("users").doc(widget.userId).update({
          "photoUrl": url,
        });

        _loadUserData(); // Перезавантажуємо дані, щоб оновити UI
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Помилка завантаження фото")));
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
        // Додаємо новий автомобіль до списку замість заміни
        await FirebaseFirestore.instance
            .collection("users")
            .doc(widget.userId)
            .update({
          "cars": FieldValue.arrayUnion([newCar.toMap()]),
        });

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
      await FirebaseFirestore.instance.collection("users").doc(widget.userId).update({
        "cars": FieldValue.arrayRemove([car.toMap()]),
      });
      _loadUserData(); // Оновлюємо UI після видалення
    }
  }
  Widget _buildReviewsButton(app_user.User user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewsListScreen(userId: widget.userId, userName: user.name,),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rate_review_rounded, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Відгуки",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Переглянути, що кажуть інші",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
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
              Icon(Icons.account_circle_outlined, size: 100, color: primaryTurquoise.withOpacity(0.5)),
              const SizedBox(height: 20),
              const Text("Ви ще не зареєстровані", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Увійдіть у наявний акаунт або створіть новий профіль для поїздок",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              // КНОПКА ВХОДУ (Заповнена)
              ElevatedButton(
                onPressed: () => _navigateTo(const LoginScreen()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTurquoise,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: const Text("Увійти", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 15),

              // КНОПКА РЕЄСТРАЦІЇ (Контурна)
              OutlinedButton(
                onPressed: () => _navigateTo(const RegistrationScreen()),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryTurquoise, width: 2),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Text("Створити акаунт", style: TextStyle(color: primaryTurquoise, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
    final user = currentUser!;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: Text(widget.isMyProfile ? "Мій профіль" : "Профіль",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
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
                  if (updatedUser != null) _loadUserData();
                } else if (value == "logout") {
                  await fbAuth.FirebaseAuth.instance.signOut();
                  if (mounted) Navigator.pushReplacementNamed(context, '/login');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: "edit", child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Редагувати")])),
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
                              ? Icon(Icons.person, size: 60, color: primaryTurquoise)
                              : null,
                        ),
                        if (widget.isMyProfile)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: primaryTurquoise,
                              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(
                    "${user.getAge() ?? '—'} років • ${user.phone}",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                      Text(" ${user.rating.toStringAsFixed(1)} ", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("(${user.tripsCompleted} поїздок)", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // НОВА КНОПКА ВІДГУКІВ
            _buildReviewsButton(user),

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
            const Text("Відгуки поки що відсутні", style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: bgTurquoiseLight, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.directions_car_filled_rounded, color: primaryTurquoise),
        ),
        title: Text("${car.brand} ${car.model}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${car.color ?? '—'} • ${car.year} рік"),
        trailing: widget.isMyProfile
            ? IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
          onPressed: () => _deleteCar(car),
        )
            : null,
      ),
    );
  }

  Widget _buildHabitRow(IconData icon, String text) {
    return Row(children: [Icon(icon, color: primaryTurquoise, size: 22), const SizedBox(width: 15), Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))]);
  }

  Widget _buildAddCarButton() {
    return GestureDetector(
      onTap: _addNewCar,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: primaryTurquoise, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: primaryTurquoise, size: 22),
            const SizedBox(width: 10),
            Text(
              "Додати автомобіль",
              style: TextStyle(
                color: primaryTurquoise,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}