import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'search_screen.dart';
import 'my_trips_screen.dart';
import 'public_profile_screen.dart';
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

  // Створюємо список екранів через метод, щоб отримати актуальний UID
  List<Widget> _buildScreens() {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return [
      const SearchScreen(from: "", to: ""),
      const MyTripsScreen(),
      const MessangerScreen(),
      PublicProfileScreen(
        userId: currentUserId,
        isMyProfile: true,
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
    final screens = _buildScreens();

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF5DD9C1), // твій бірюзовий
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
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
