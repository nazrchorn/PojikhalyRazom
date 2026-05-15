import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'my_trips_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex; // новий параметр

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex; // беремо стартовий індекс
  }

  final List<Widget> _screens = [
    const SearchScreen(from: "", to: ""), // екран пошуку
    const MyTripsScreen(),                // екран моїх поїздок
    const ProfileScreen(), // екран профілю
   // const MessangerScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Пошук',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Мої поїздки',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Профіль',
          ),
         // BottomNavigationBarItem(
         //   icon: Icon(Icons.mark_unread_chat_alt_outlined),
          //  label: 'Чат',
         // ),
        ],
      ),
    );
  }
}
