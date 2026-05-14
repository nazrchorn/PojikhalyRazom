import 'package:flutter/material.dart';
import 'trips_list_screen.dart';

class SearchScreen extends StatefulWidget {
  final String from;
  final String to;

  const SearchScreen({
    super.key,
    required this.from,
    required this.to,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _fromController;
  late TextEditingController _toController;

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(text: widget.from);
    _toController = TextEditingController(text: widget.to);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _onSearch() {
    if (_fromController.text.isNotEmpty && _toController.text.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TripsListScreen(
            fromCity: _fromController.text,
            toCity: _toController.text,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пошук поїздок')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _fromController,
              decoration: const InputDecoration(
                labelText: 'Звідки',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _toController,
              decoration: const InputDecoration(
                labelText: 'Куди',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _onSearch,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Знайти поїздки'),
            ),
          ],
        ),
      ),
    );
  }
}