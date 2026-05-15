import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_selectedImage == null) return widget.user.photoUrl;
    final ref = FirebaseStorage.instance.ref().child("profile_photos/$userId.jpg");
    await ref.putFile(_selectedImage!);
    return await ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Редагувати профіль")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : (widget.user.photoUrl != null
                    ? NetworkImage(widget.user.photoUrl!)
                    : const AssetImage("assets/default_avatar.png") as ImageProvider),
              ),
            ),
            const SizedBox(height: 20),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Ім'я")),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Телефон")),

            Card(
              child: ListTile(
                leading: const Icon(Icons.wc),
                title: Text(widget.user.gender == "female" ? "Жінка" : "Чоловік"),
                subtitle: const Text("Стать (не редагується)"),
              ),
            ),

            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cake),
                title: Text(
                  widget.user.birthDate != null
                      ? "${widget.user.birthDate!.day}.${widget.user.birthDate!.month}.${widget.user.birthDate!.year}"
                      : "Не вказано",
                ),
                subtitle: const Text("Дата народження (вік: обчислюється)"),
              ),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                final photoUrl = await _uploadImage(widget.user.id);

                final updatedUser = User(
                  id: widget.user.id,
                  name: _nameController.text,
                  email: _emailController.text,
                  phone: _phoneController.text,
                  rating: widget.user.rating,
                  cars: widget.user.cars,
                  createdAt: widget.user.createdAt,
                  photoUrl: photoUrl,
                  gender: widget.user.gender, // ✅ стать лишається незмінною
                  birthDate: widget.user.birthDate, // ✅ дата народження не редагується
                  isTalkative: widget.user.isTalkative,
                  musicType: widget.user.musicType,
                  isSmoker: widget.user.isSmoker,
                  allowSmoking: widget.user.allowSmoking,
                  tripsCompleted: widget.user.tripsCompleted,
                );


                await FirebaseFirestore.instance.collection("users").doc(updatedUser.id).set(updatedUser.toMap());

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Дані оновлено ✅")),
                );

                Navigator.pop(context, updatedUser);
              },
              child: const Text("Зберегти"),
            ),
          ],
        ),
      ),
    );
  }
}
