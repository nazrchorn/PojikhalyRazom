import 'package:flutter/material.dart';
import 'trips_list_screen.dart';
import 'city_search_screen.dart'; // Новий екран (див. нижче)

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
  late String _fromCity;
  late String _toCity;

  final Color primaryTurquoise = const Color(0xFF5DD9C1);

  @override
  void initState() {
    super.initState();
    _fromCity = widget.from;
    _toCity = widget.to;
  }

  // Функція для відкриття екрану вибору міста
  Future<void> _selectCity(bool isFrom) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CitySearchScreen(
          title: isFrom ? 'Звідки їдемо?' : 'Куди прямуємо?',
        ),
      ),
    );

    // result тепер — це Map<String, dynamic>
    if (result != null && mounted) {
      setState(() {
        if (isFrom) {
          _fromCity = result['city']; // Беремо назву міста
          // Можеш також зберегти координати в змінні, якщо треба
        } else {
          _toCity = result['city'];
        }
      });
    }
  }

  void _onSearch() {
    if (_fromCity.isNotEmpty && _toCity.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TripsListScreen(
            fromCity: _fromCity,
            toCity: _toCity,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Будь ласка, оберіть обидва міста")),
      );
    }
  }

  Widget _buildCitySelector(String label, String value, IconData icon, bool isFrom) {
    final isEmpty = value.isEmpty;
    return InkWell(
      onTap: () => _selectCity(isFrom),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryTurquoise),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    isEmpty ? "Оберіть місто" : value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isEmpty ? FontWeight.normal : FontWeight.bold,
                      color: isEmpty ? Colors.grey : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Пошук поїздок'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildCitySelector("Звідки", _fromCity, Icons.radio_button_checked, true),
            const SizedBox(height: 12),
            _buildCitySelector("Куди", _toCity, Icons.location_on, false),

            const Spacer(),

            ElevatedButton(
              onPressed: _onSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTurquoise,
                minimumSize: const Size.fromHeight(55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Знайти поїздки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}