import 'dart:async';
import 'package:flutter/material.dart';
import '../services/map_service.dart';

class CitySearchScreen extends StatefulWidget {
  final String title;

  const CitySearchScreen({super.key, required this.title});

  @override
  State<CitySearchScreen> createState() => _CitySearchScreenState();
}

class _CitySearchScreenState extends State<CitySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapService _mapService = MapService();

  List<dynamic> _suggestions = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final suggestions = await _mapService.searchAddresses(query);

      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Перевір підключення до інтернету";
        _isLoading = false;
      });
      debugPrint("Деталі помилки: $e");
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _fetchSuggestions(query);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Наприклад: Львів чи Lviv",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF5DD9C1)),
                suffixIcon: _isLoading
                    ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5DD9C1)),
                )
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _suggestions = [];
                      _errorMessage = null;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Відображення помилки, якщо вона є
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),

          Expanded(
            child: _suggestions.isEmpty && _searchController.text.length >= 2 && !_isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text("Нічого не знайдено", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final props = _suggestions[index]['properties'];
                final coords = _suggestions[index]['geometry']['coordinates'];

                // Пріоритет вибору назви
                final String cityName = props['locality'] ?? props['name'] ?? props['label'] ?? "Невідомо";
                final String fullLabel = props['label'] ?? "";

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5DD9C1).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on, color: Color(0xFF5DD9C1), size: 20),
                  ),
                  title: Text(cityName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(fullLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.pop(context, {
                      'city': cityName,
                      'address': fullLabel,
                      'lat': coords[1],
                      'lng': coords[0],
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}