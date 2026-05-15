import 'package:app1/screens/stops_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'trip_summary_screen.dart';

class RouteSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> origin;
  final Map<String, dynamic> destination;
  final String apiKey;

  const RouteSelectionScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.apiKey,
  });

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> routes = [];
  int? selectedRouteIndex;

  Future<void> _fetchRoutes() async {
    final start = "${widget.origin['lng']},${widget.origin['lat']}";
    final end = "${widget.destination['lng']},${widget.destination['lat']}";

    final url =
        "https://api.openrouteservice.org/v2/directions/driving-car"
        "?api_key=${widget.apiKey}&start=$start&end=$end&alternative_routes=true";

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features == null || features.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Маршрутів не знайдено")),
          );
          return;
        }

        // route_selection_screen.dart

        final newRoutes = features.map((f) {
          final coords = f['geometry']['coordinates'] as List;
          final polyline = coords.map((c) => LatLng(c[1], c[0])).toList();
          return {
            "polyline": polyline,
            "geometry": f['geometry'], // <--- ОБОВ'ЯЗКОВО ДОДАЙТЕ ЦЕЙ РЯДОК
            "duration": f['properties']['summary']['duration'],
            "distance": f['properties']['summary']['distance'],
          };
        }).toList();

        setState(() {
          routes = newRoutes;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("HTTP ${response.statusCode}: ${response.reasonPhrase}")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Виняток: $e")),
      );
    }
  }

  void _confirmRoute() {
    if (selectedRouteIndex == null) return;
    final selectedRoute = routes[selectedRouteIndex!];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StopSelectionScreen(
          origin: widget.origin,
          destination: widget.destination,
          selectedRoute: routes[selectedRouteIndex!],
          apiKey: widget.apiKey,
        ),
      ),
    );
  }



  /// Перевіряє, чи точка кліку близька до маршруту
  void _handleTap(TapPosition tapPosition, LatLng latlng) {
    const threshold = 50.0; // у метрах
    final distance = Distance();

    for (var i = 0; i < routes.length; i++) {
      final polyline = routes[i]['polyline'] as List<LatLng>;
      for (var j = 0; j < polyline.length - 1; j++) {
        final d = distance.distance(latlng, polyline[j]);
        if (d < threshold) {
          setState(() => selectedRouteIndex = i);

          return;
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Вибір маршруту")),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.origin['lat'], widget.origin['lng']),
              initialZoom: 7,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.pojikhaly_razom',
              ),
              if (routes.isNotEmpty)
                PolylineLayer(
                  polylines: routes.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final r = entry.value;
                    return Polyline(
                      points: r['polyline'],
                      strokeWidth: 4,
                      color: selectedRouteIndex == idx ? Colors.blue : Colors.grey,
                    );
                  }).toList(),
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.origin['lat'], widget.origin['lng']),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on,
                        color: Colors.green, size: 40),
                  ),
                  Marker(
                    point: LatLng(widget.destination['lat'], widget.destination['lng']),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on,
                        color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          if (routes.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...routes.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final r = entry.value;
                      final durationMin = (r['duration'] / 60).round();
                      final distanceKm = (r['distance'] / 1000).toStringAsFixed(1);
                      return ListTile(
                        title: Text(
                          "Маршрут ${idx + 1}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          "$durationMin хв • $distanceKm км",
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: selectedRouteIndex == idx
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() => selectedRouteIndex = idx);

                        },
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedRouteIndex != null ? _confirmRoute : null,
                          child: const Text(
                            "Підтвердити маршрут",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
