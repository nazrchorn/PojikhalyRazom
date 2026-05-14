import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // 🔑 додали
import 'firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'screens/main_screen.dart';
import 'screens/route_selection_screen.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 🔑 Тут зберігаємо ключі
  static const String orsKey =
      "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjBiOTQ0MDNkMjQyNTQyNzRhODg4M2ZkNzhlZTM2MWM3IiwiaCI6Im11cm11cjY0In0=";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pojikhaly Razom',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(), // стартовий екран
      routes: {
        '/routeSelection': (context) => RouteSelectionScreen(
          origin: {"lat": 49.8408, "lng": 24.0036, "address": "Львів"},
          destination: {"lat": 48.8448, "lng": 23.4448, "address": "Самбір"},
          apiKey: orsKey,
        ),
      },
    );
  }
}
