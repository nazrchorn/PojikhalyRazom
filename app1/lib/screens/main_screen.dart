import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Stream<int> _unreadMessagesCountStream(String uid) {
    return FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Widget _chatTabIcon(int unreadCount) {
    if (unreadCount <= 0) {
      return const Icon(Icons.mark_unread_chat_alt_outlined);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.mark_unread_chat_alt_outlined),
        Positioned(
          right: -8,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
            child: Text(
              unreadCount > 99 ? '99+' : '$unreadCount',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: StreamBuilder<int>(
        stream: currentUserId.isEmpty
            ? Stream<int>.value(0)
            : _unreadMessagesCountStream(currentUserId),
        initialData: 0,
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;

          return BottomNavigationBar(
            backgroundColor: Colors.white,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: const Color(0xFF5DD9C1),
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Пошук',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.directions_car),
                label: 'Поїздки',
              ),
              BottomNavigationBarItem(
                icon: _chatTabIcon(unreadCount),
                label: 'Чат',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Профіль',
              ),
            ],
          );
        },
      ),
    );
  }
}
