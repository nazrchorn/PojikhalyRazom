import 'package:flutter/material.dart';

void main() {
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

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Контролери для зчитування тексту з полів
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  // Тимчасовий список поїздок (імітація бази даних)
  List<Map<String, String>> trips = [
    {'from': 'Київ', 'to': 'Львів', 'price': '400 грн', 'driver': 'Олексій', 'time': '12:00'},
    {'from': 'Київ', 'to': 'Одеса', 'price': '500 грн', 'driver': 'Марія', 'time': '14:30'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Куди їдемо?')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Поле "Звідки"
            TextField(
              controller: _fromController,
              decoration: const InputDecoration(
                labelText: 'Звідки',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 10),
            // Поле "Куди"
            TextField(
              controller: _toController,
              decoration: const InputDecoration(
                labelText: 'Куди',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
            const SizedBox(height: 20),
            // Кнопка пошуку
            ElevatedButton(
              onPressed: () {
                // Тут буде логіка запиту до вашого Backend
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
            // Список знайдених поїздок
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
                      onTap: () {
                        // Тут буде перехід на деталі поїздки
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}