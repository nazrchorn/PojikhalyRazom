import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ArrivalSearchScreen extends StatefulWidget {
  const ArrivalSearchScreen({super.key});

  @override
  State<ArrivalSearchScreen> createState() => _ArrivalSearchScreenState();
}

class _ArrivalSearchScreenState extends State<ArrivalSearchScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

  final Color primaryTurquoise = const Color(0xFF5DD9C1);

  Future<void> _searchAddress(String query) async {
    if (query.trim().length < 2) {
      setState(() => suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    // Використовуємо Nominatim для стабільності та уникнення помилок 404/403
    final url = "https://nominatim.openstreetmap.org/search?"
        "q=${Uri.encodeComponent(query)}"
        "&format=json&addressdetails=1&limit=10&countrycodes=ua&accept-language=uk";

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Pojikhaly_Razom_App_Student', // Обов'язково для стабільної роботи з OSM
      });

      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          suggestions = data.map((item) {
            final addr = item['address'];
            // Витягуємо місто або населений пункт
            final String city = addr['city'] ?? addr['town'] ?? addr['village'] ?? "Невідомо";

            return {
              "city": city,
              "address": item['display_name'],
              "lat": double.parse(item['lat']),
              "lng": double.parse(item['lon']),
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Помилка пошуку прибуття: $e");
    }
  }

  void _onChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // Затримка 800мс, щоб не викликати помилку сервера 503
    _debounce = Timer(const Duration(milliseconds: 800), () => _searchAddress(val));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Куди прямуємо?"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: "Введіть місто або конкретну адресу...",
                prefixIcon: Icon(Icons.flag_rounded, color: primaryTurquoise),
                suffixIcon: _isLoading
                    ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2)
                )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none
                ),
              ),
            ),
          ),
          Expanded(
            child: suggestions.isEmpty && _controller.text.length >= 2 && !_isLoading
                ? const Center(child: Text("Місце не знайдено"))
                : ListView.separated(
              itemCount: suggestions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = suggestions[index];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryTurquoise.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sports_score, color: primaryTurquoise, size: 20),
                  ),
                  title: Text(s['address'], maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(s['city']),
                  onTap: () => Navigator.pop(context, s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}