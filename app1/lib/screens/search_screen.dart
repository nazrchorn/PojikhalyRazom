import 'package:flutter/material.dart';
import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  int _selectedIndex = 0;

  List<Map<String, String>> trips = [
    {'from': 'Київ', 'to': 'Львів', 'price': '400 грн', 'driver': 'Олексій', 'time': '12:00'},
    {'from': 'Київ', 'to': 'Одеса', 'price': '500 грн', 'driver': 'Марія', 'time': '14:30'},
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Куди їдемо?')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _fromController, decoration: const InputDecoration(labelText: 'Звідки', prefixIcon: Icon(Icons.location_on_outlined))),
            const SizedBox(height: 10),
            TextField(controller: _toController, decoration: const InputDecoration(labelText: 'Куди', prefixIcon: Icon(Icons.flag_outlined))),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print('Шукаємо з ${_fromController.text} до ${_toController.text}');
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Знайти поїздку'),
            ),
            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Доступні поїздки:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                      title: Text('${trips[index]['from']} → ${trips[index]['to']}'),
                      subtitle: Text('Водій: ${trips[index]['driver']} • Час: ${trips[index]['time']}'),
                      trailing: Text(
                        trips[index]['price']!,
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Пошук'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Мій профіль'),
        ],
      ),
    );
  }
}