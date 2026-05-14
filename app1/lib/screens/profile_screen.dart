import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user.dart';
import 'login_screen.dart';
import 'registration_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? currentUser;

  Future<void> _loadUser(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
      if (doc.exists) {
        setState(() {
          currentUser = User.fromMap(doc.id, doc.data()!);
        });
      }
    } catch (e) {
      debugPrint("Помилка доступу до Firestore: $e");
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (currentUser == null) {
      debugPrint("User not loaded yet");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Користувач ще не завантажений")),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final file = File(pickedFile.path);

        final ref = FirebaseStorage.instance
            .ref()
            .child("profile_photos/${currentUser!.id}/avatar.jpg");

        await ref.putFile(file);
        final url = await ref.getDownloadURL();

        await FirebaseFirestore.instance.collection("users").doc(currentUser!.id).set({
          "photoUrl": url,
        }, SetOptions(merge: true));

        if (!mounted) return;
        setState(() {
          currentUser = User(
            id: currentUser!.id,
            name: currentUser!.name,
            email: currentUser!.email,
            phone: currentUser!.phone,
            rating: currentUser!.rating,
            car: currentUser!.car,
            createdAt: currentUser!.createdAt,
            photoUrl: url,
            gender: currentUser!.gender, // ✅ зберігаємо стать
          );
        });
      }
    } catch (e) {
      debugPrint("Помилка при завантаженні фото: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не вдалося завантажити фото")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = fbAuth.FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Мій профіль")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                child: const Text("Увійти"),
                onPressed: () async {
                  final uid = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                  if (uid != null) {
                    await _loadUser(uid);
                  }
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: const Text("Зареєструватися"),
                onPressed: () async {
                  final uid = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                  );
                  if (uid != null) {
                    await _loadUser(uid);
                  }
                },
              ),
            ],
          ),
        ),
      );
    } else {
      if (currentUser == null) {
        _loadUser(firebaseUser.uid);
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text("Мій профіль"),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == "edit") {
                  final updatedUser = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EditProfileScreen(user: currentUser!)),
                  );
                  if (updatedUser != null) setState(() => currentUser = updatedUser);
                } else if (value == "logout") {
                  await fbAuth.FirebaseAuth.instance.signOut();
                  setState(() => currentUser = null);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: "edit", child: Text("Редагувати дані")),
                const PopupMenuItem(value: "logout", child: Text("Вийти")),
              ],
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickAndUploadPhoto,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: currentUser!.photoUrl != null
                      ? NetworkImage(currentUser!.photoUrl!)
                      : const AssetImage("assets/default_avatar.png") as ImageProvider,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(currentUser!.name),
                  subtitle: const Text("Ім'я"),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.email),
                  title: Text(currentUser!.email),
                  subtitle: const Text("Email"),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(currentUser!.phone),
                  subtitle: const Text("Телефон"),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.wc),
                  title: Text(currentUser!.gender == "female" ? "Жінка" : "Чоловік"),
                  subtitle: const Text("Стать"),
                ),
              ),
              if (currentUser!.car != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.directions_car),
                    title: Text("${currentUser!.car!.brand} ${currentUser!.car!.model}"),
                    subtitle: Text("Рік: ${currentUser!.car!.year}, Місць: ${currentUser!.car!.seats}"),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }
}
