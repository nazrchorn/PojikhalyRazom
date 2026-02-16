import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import '../models/user.dart';
import '../models/car.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _carBrandController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carYearController = TextEditingController();
  final _carSeatsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Реєстрація")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Ім'я")),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Телефон")),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Пароль"), obscureText: true),
            const SizedBox(height: 20),
            const Text("Інформація про авто", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _carBrandController, decoration: const InputDecoration(labelText: "Марка")),
            TextField(controller: _carModelController, decoration: const InputDecoration(labelText: "Модель")),
            TextField(controller: _carYearController, decoration: const InputDecoration(labelText: "Рік"), keyboardType: TextInputType.number),
            TextField(controller: _carSeatsController, decoration: const InputDecoration(labelText: "Кількість місць"), keyboardType: TextInputType.number),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Створюємо акаунт у Firebase Auth
                  fbAuth.UserCredential cred = await fbAuth.FirebaseAuth.instance.createUserWithEmailAndPassword(
                    email: _emailController.text.trim(),
                    password: _passwordController.text.trim(),
                  );

                  final car = Car(
                    brand: _carBrandController.text,
                    model: _carModelController.text,
                    year: int.tryParse(_carYearController.text) ?? 0,
                    seats: int.tryParse(_carSeatsController.text) ?? 0,
                  );

                  final user = User(
                    id: cred.user!.uid,
                    name: _nameController.text,
                    email: _emailController.text,
                    phone: _phoneController.text,
                    rating: 0.0,
                    car: car,
                    createdAt: DateTime.now(),
                  );

                  await FirebaseFirestore.instance.collection("users").doc(user.id).set(user.toMap());

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Користувач зареєстрований ✅")),
                  );

                  Navigator.pop(context, user);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Помилка: $e")),
                  );
                }
              },
              child: const Text("Зареєструватися"),
            ),
          ],
        ),
      ),
    );
  }
}