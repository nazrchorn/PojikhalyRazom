import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Увійти")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Пароль"), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Вхід через Firebase Auth
                  fbAuth.UserCredential cred = await fbAuth.FirebaseAuth.instance.signInWithEmailAndPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                  );

                  // Підтягування профілю з Firestore
                  final doc = await FirebaseFirestore.instance.collection("users").doc(cred.user!.uid).get();
                  if (doc.exists) {
                    final user = User.fromMap(doc.id, doc.data()!);
                    Navigator.pop(context, user); // повертаємо користувача у ProfileScreen
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Профіль не знайдено у Firestore")),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Помилка входу: $e")),
                  );
                }
              },
              child: const Text("Увійти"),
            ),
          ],
        ),
      ),
    );
  }
}