import 'dart:async';
import 'package:flutter/material.dart';
import '../services/map_service.dart';

class DepartureSearchScreen extends StatefulWidget {
  const DepartureSearchScreen({super.key});

  @override
  State<DepartureSearchScreen> createState() => _DepartureSearchScreenState();
}

class _DepartureSearchScreenState extends State<DepartureSearchScreen> {
  final _controller = TextEditingController();
  final MapService _mapService = MapService();

  List<Map<String, dynamic>> suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

  Future<void> _searchAddress(String query) async {
    if (query.trim().length < 2) {
      setState(() => suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await _mapService.searchAddressesForDeparture(query);
      setState(() {
        suggestions = results;
        _isLoading = false;
      });
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
      backgroundColor: const Color(0xFFF6FCFA),
      appBar: AppBar(
        title: const Text("Точка відправлення"),
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
                hintText: "Вулиця, номер будинку або місто...",
                prefixIcon: const Icon(Icons.location_on, color: Color(0xFF2F8F7F)),
                suffixIcon: _isLoading
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
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