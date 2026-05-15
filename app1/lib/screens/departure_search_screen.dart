import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class DepartureSearchScreen extends StatefulWidget {
  const DepartureSearchScreen({super.key});

  @override
  State<DepartureSearchScreen> createState() => _DepartureSearchScreenState();
}

class _DepartureSearchScreenState extends State<DepartureSearchScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

  Future<void> _searchAddress(String query) async {
    if (query.trim().length < 2) {
      setState(() => suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    // Використовуємо Nominatim для стабільності
    final url = "https://nominatim.openstreetmap.org/search?"
        "q=${Uri.encodeComponent(query)}"
        "&format=json&addressdetails=1&limit=10&countrycodes=ua&accept-language=uk";

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Pojikhaly_Razom_App',
      });

      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          suggestions = data.map((item) {
            final addr = item['address'];
            return {
              "city": addr['city'] ?? addr['town'] ?? addr['village'] ?? "Невідомо",
              "country": addr['country'] ?? "Україна",
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
      debugPrint("Помилка пошуку: $e");
    }
  }

  void _onChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
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
        title: const Text("Точка відправлення"),
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
                hintText: "Вулиця, номер будинку або місто...",
                prefixIcon: const Icon(Icons.location_on, color: Color(0xFF5DD9C1)),
                suffixIcon: _isLoading ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: suggestions.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final s = suggestions[index];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(s['address'], maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text("${s['city']}, ${s['country']}"),
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