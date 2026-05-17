import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'trip_summary_screen.dart';
import 'package:flutter/services.dart';

class StopSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> origin;
  final Map<String, dynamic> destination;
  final Map<String, dynamic> selectedRoute;
  final String apiKey;

  const StopSelectionScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.selectedRoute,
    required this.apiKey,
  });

  @override
  State<StopSelectionScreen> createState() => _StopSelectionScreenState();
}

class _StopSelectionScreenState extends State<StopSelectionScreen> {
  List<Map<String, dynamic>> suggestedStops = [];
  List<Map<String, dynamic>> selectedStops = [];
  bool isLoading = true;
  final Color accentColor = const Color(0xFF1F6F66);

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  double _getDistanceFromRoute(LatLng point) {
    try {
      final polyline = widget.selectedRoute['polyline'] as List<LatLng>;
      final distance = const Distance();
      double minDistance = double.infinity;
      for (var routePoint in polyline) {
        double d = distance.distance(point, routePoint);
        if (d < minDistance) minDistance = d;
      }
      return minDistance / 1000;
    } catch (e) {
      return 0.0;
    }
  }


  Future<void> _loadStops() async {
    setState(() => isLoading = true);

    try {
      // 1. Завантажуємо JSON з assets
      final String response = await rootBundle.loadString('assets/ukraine_cities.json');
      final List<dynamic> data = json.decode(response);

      final List<LatLng> polyline = List<LatLng>.from(widget.selectedRoute['polyline']);
      final distance = const Distance();
      final List<Map<String, dynamic>> results = [];

      // Координати старту та фінішу для фільтрації
      final startPos = LatLng(widget.origin['lat'], widget.origin['lng']);
      final endPos = LatLng(widget.destination['lat'], widget.destination['lng']);

      for (var cityData in data) {
        final cityPos = LatLng(cityData['lat'], cityData['lng']);

        // Відстань від міста до старту та фінішу
        final double dToStart = distance.as(LengthUnit.Meter, cityPos, startPos);
        final double dToEnd = distance.as(LengthUnit.Meter, cityPos, endPos);

        // Пропускаємо міста, які є занадто близько до старту/фінішу (3 км)
        if (dToStart < 3000 || dToEnd < 3000) continue;

        // 2. Математична перевірка: чи проходить маршрут крізь місто (радіус 6 км)
        bool isNearRoute = false;
        // Оптимізація: перевіряємо кожну 10-ту точку маршруту для швидкості
        for (int i = 0; i < polyline.length; i += 10) {
          if (distance.as(LengthUnit.Meter, cityPos, polyline[i]) < 6000) {
            isNearRoute = true;
            break;
          }
        }

        if (isNearRoute) {
          results.add({
            "city": cityData['name'],
            "lat": cityData['lat'],
            "lng": cityData['lng'],
            "distToRoute": _getDistanceFromRoute(cityPos), // твоя функція розрахунку
          });
        }
      }

      if (mounted) {
        setState(() {
          suggestedStops = results;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Помилка завантаження міст: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Оберіть зупинки"),
        backgroundColor: accentColor,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : Column(
        children: [
          Expanded(
            child: suggestedStops.isEmpty
                ? const Center(child: Text("Міст не знайдено"))
                : ListView.builder(
              itemCount: suggestedStops.length,
              itemBuilder: (context, index) {
                final stop = suggestedStops[index];
                final isSelected = selectedStops.any((s) => s['city'] == stop['city']);
                return CheckboxListTile(
                  activeColor: accentColor,
                  title: Text(stop['city']),
                  subtitle: Text("${stop['distToRoute'].toStringAsFixed(1)} км від траси"),
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      val! ? selectedStops.add(stop) : selectedStops.removeWhere((s) => s['city'] == stop['city']);
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TripSummaryScreen(
                      title: "Підсумок поїздки",
                      origin: widget.origin,
                      destination: widget.destination,
                      selectedRoute: widget.selectedRoute,
                      selectedStops: selectedStops,
                    ),
                  ),
                );
              },
              child: const Text("Підтвердити", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
} // <--- Оця дужка має закривати клас останньою