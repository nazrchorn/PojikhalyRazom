import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/car.dart';

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
  late TextEditingController _carBrandController;
  late TextEditingController _carModelController;
  late TextEditingController _carYearController;
  late TextEditingController _carSeatsController;

  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone);
    _carBrandController = TextEditingController(text: widget.user.car?.brand ?? "");
    _carModelController = TextEditingController(text: widget.user.car?.model ?? "");
    _carYearController = TextEditingController(text: widget.user.car?.year.toString() ?? "");
    _carSeatsController = TextEditingController(text: widget.user.car?.seats.toString() ?? "");
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

            // ✅ Стать показуємо, але не редагуємо
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.wc),
                title: Text(widget.user.gender == "female" ? "Жінка" : "Чоловік"),
                subtitle: const Text("Стать (не редагується)"),
              ),
            ),

            const SizedBox(height: 20),
            const Text("Інформація про авто", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _carBrandController, decoration: const InputDecoration(labelText: "Марка")),
            TextField(controller: _carModelController, decoration: const InputDecoration(labelText: "Модель")),
            TextField(controller: _carYearController, decoration: const InputDecoration(labelText: "Рік"), keyboardType: TextInputType.number),
            TextField(controller: _carSeatsController, decoration: const InputDecoration(labelText: "Кількість місць"), keyboardType: TextInputType.number),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                final photoUrl = await _uploadImage(widget.user.id);

                final car = Car(
                  brand: _carBrandController.text,
                  model: _carModelController.text,
                  year: int.tryParse(_carYearController.text) ?? 0,
                  seats: int.tryParse(_carSeatsController.text) ?? 0,
                );

                final updatedUser = User(
                  id: widget.user.id,
                  name: _nameController.text,
                  email: _emailController.text,
                  phone: _phoneController.text,
                  rating: widget.user.rating,
                  car: car,
                  createdAt: widget.user.createdAt,
                  photoUrl: photoUrl,
                  gender: widget.user.gender, // ✅ стать лишається незмінною
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
