import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/search_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Ініціалізація Firebase
  runApp(const MyStartupApp());
}

class MyStartupApp extends StatelessWidget {
  const MyStartupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarPool Analog',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SearchScreen(),
    );
  }
}