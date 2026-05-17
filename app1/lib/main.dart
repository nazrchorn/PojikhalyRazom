import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/route_selection_screen.dart';
import 'screens/driver_booking_request_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void _handleNotificationTap(Map<String, dynamic> data) {
  if (FirebaseAuth.instance.currentUser == null) return;

  final requestId = (data['bookingRequestId'] ?? '').toString().trim();
  final messageType = (data['messageType'] ?? data['type'] ?? '').toString();
  final bool isBookingFlow =
      requestId.isNotEmpty || messageType.startsWith('booking_request');

  if (!isBookingFlow || requestId.isEmpty) return;

  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;

  navigator.push(
    MaterialPageRoute(
      builder: (_) => DriverBookingRequestScreen(requestId: requestId),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
  await NotificationService.instance.initialize(
    onNotificationTap: _handleNotificationTap,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String orsKey = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjBiOTQ0MDNkMjQyNTQyNzRhODg4M2ZkNzhlZTM2MWM3IiwiaCI6Im11cm11cjY0In0=";

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: rootNavigatorKey,
          title: 'Pojikhaly Razom',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          // Стрім слухає: залогінений юзер чи ні
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF1F6F66))));
              }
              if (snapshot.hasData) {
                return const MainScreen();
              }
              return const LoginScreen(); // Якщо не залогінений — на вхід
            },
          ),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegistrationScreen(),
            '/main': (context) => const MainScreen(),
            '/routeSelection': (context) => RouteSelectionScreen(
              origin: {"lat": 49.8408, "lng": 24.0036, "address": "Львів"},
              destination: {"lat": 48.8448, "lng": 23.4448, "address": "Самбір"},
              apiKey: orsKey,
            ),
          },
        );
      },
    );
  }
}