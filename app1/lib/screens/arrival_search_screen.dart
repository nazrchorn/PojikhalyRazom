import 'dart:async';
import 'package:flutter/material.dart';
import '../services/map_service.dart';

class ArrivalSearchScreen extends StatefulWidget {
  const ArrivalSearchScreen({super.key});

  @override
  State<ArrivalSearchScreen> createState() => _ArrivalSearchScreenState();
}

class _ArrivalSearchScreenState extends State<ArrivalSearchScreen> {
  final _controller = TextEditingController();
  final MapService _mapService = MapService();

  List<Map<String, dynamic>> suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

  final Color primaryTurquoise = const Color(0xFF2F8F7F);

  Future<void> _searchAddress(String query) async {
    if (query.trim().length < 2) {
      setState(() => suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await _mapService.searchAddressesForArrival(query);
      setState(() {
        suggestions = results;
        _isLoading = false;
      });
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
      backgroundColor: const Color(0xFFF6FCFA),
      appBar: AppBar(
        title: const Text("Куди прямуємо?"),
        backgroundColor: const Color(0xFFF4FBF9),
        surfaceTintColor: const Color(0xFFF4FBF9),
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
                      color: primaryTurquoise.withValues(alpha: 0.1),
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