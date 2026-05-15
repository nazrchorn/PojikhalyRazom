import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Додали для отримання UID
import 'search_screen.dart';
import 'my_trips_screen.dart';
import 'public_profile_screen.dart'; // Імпортуємо наш новий універсальний екран
import 'messanger_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _screens = [
    const SearchScreen(from: "", to: ""), // екран пошуку
    const MyTripsScreen(),                // екран моїх поїздок
    const MessangerScreen(),
    const ProfileScreen(), // екран профілю
  ];

  // Створюємо список екранів через метод, щоб отримати актуальний UID
  List<Widget> _buildScreens() {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return [
      const SearchScreen(from: "", to: ""),
      const MyTripsScreen(),
      // Ось тут ми викликаємо новий екран профілю
      PublicProfileScreen(
        userId: currentUserId,
        isMyProfile: true, // Вмикаємо кнопки редагування та виходу
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Отримуємо список екранів
    final screens = _buildScreens();

    return Scaffold(
      // Використовуємо IndexedStack, щоб стан екранів зберігався при перемиканні
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black87,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF5DD9C1), // Твій бірюзовий колір
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Щоб іконки не "стрибали"
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Пошук',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Поїздки',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mark_unread_chat_alt_outlined),
            label: 'Чат',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Профіль',
          ),
        ],
      ),
    );
  }
}