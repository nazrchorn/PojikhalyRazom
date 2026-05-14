import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Поля для машини
  final TextEditingController carBrandController = TextEditingController();
  final TextEditingController carModelController = TextEditingController();
  final TextEditingController carYearController = TextEditingController();
  final TextEditingController carSeatsController = TextEditingController();

  Future<void> _register() async {
    try {
      // 1. Створюємо акаунт у Firebase Auth
      final credential = await fbAuth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final firebaseUser = credential.user;

      // 2. Створюємо документ у Firestore з id = uid
      await FirebaseFirestore.instance.collection("users").doc(firebaseUser!.uid).set({
        "name": nameController.text.trim(),
        "email": firebaseUser.email,
        "phone": phoneController.text.trim(),
        "createdAt": FieldValue.serverTimestamp(),
        "photoUrl": null, // поки що без фото
        "car": {
          "brand": carBrandController.text.trim(),
          "model": carModelController.text.trim(),
          "year": int.tryParse(carYearController.text.trim()),
          "seats": int.tryParse(carSeatsController.text.trim()),
        }
      });

      // 3. Повертаємо користувача назад у профіль
      Navigator.pop(context, {
        "id": firebaseUser.uid,
        "name": nameController.text.trim(),
        "email": firebaseUser.email,
        "phone": phoneController.text.trim(),
        "photoUrl": null,
        "car": {
          "brand": carBrandController.text.trim(),
          "model": carModelController.text.trim(),
          "year": int.tryParse(carYearController.text.trim()),
          "seats": int.tryParse(carSeatsController.text.trim()),
        }
      });
    } catch (e) {
      debugPrint("Помилка при реєстрації: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не вдалося зареєструватися")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Реєстрація")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Ім'я")),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Телефон")),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Пароль"), obscureText: true),
            const SizedBox(height: 20),
            const Text("Інформація про машину", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: carBrandController, decoration: const InputDecoration(labelText: "Бренд")),
            TextField(controller: carModelController, decoration: const InputDecoration(labelText: "Модель")),
            TextField(controller: carYearController, decoration: const InputDecoration(labelText: "Рік")),
            TextField(controller: carSeatsController, decoration: const InputDecoration(labelText: "Кількість місць")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _register,
              child: const Text("Зареєструватися"),
            ),
          ],
        ),
      ),
    );
  }
}