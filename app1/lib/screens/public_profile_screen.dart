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
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (doc.exists && mounted) {
        setState(() {
          currentUser = app_user.User.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Помилка завантаження: $e");
    }
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: primaryTurquoise)));
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

            const SizedBox(height: 30),
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
            if (user.cars.isNotEmpty) ...[
              _buildSectionTitle("Транспорт"),
              const SizedBox(height: 12),
              ...user.cars.map((car) => Column(
                    children: [
                      _buildCarCard(car),
                      const SizedBox(height: 12),
                    ],
                  )),
              if (widget.isMyProfile) _buildAddCarButton(),
            ] else if (widget.isMyProfile) ...[
              _buildSectionTitle("Транспорт"),
              const SizedBox(height: 12),
              _buildAddCarButton(),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade100)),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: bgTurquoiseLight, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.directions_car_filled_rounded, color: primaryTurquoise),
        ),
        title: Text("${car.brand} ${car.model}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Колір: ${car.color ?? '—'} • Рік: ${car.year} • Місць: ${car.seats}"),
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