import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/trip.dart';

class TripDetailsMapScreen extends StatefulWidget {
  final Trip trip;
  final String apiKey;

  const TripDetailsMapScreen({
    super.key,
    required this.trip,
    required this.apiKey,
  });

  @override
  State<TripDetailsMapScreen> createState() => _TripDetailsMapScreenState();
}

class _TripDetailsMapScreenState extends State<TripDetailsMapScreen> {
  final MapController _mapController = MapController();
  List<LatLng> polylinePoints = [];
  double? duration;
  double? distance;

  Future<void> _fetchRoute() async {
    final start = "${widget.trip.origin.lng},${widget.trip.origin.lat}";
    final end = "${widget.trip.destination.lng},${widget.trip.destination.lat}";

    final url =
        "https://api.openrouteservice.org/v2/directions/driving-car"
        "?api_key=${widget.apiKey}&start=$start&end=$end";

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

        final coords = features[0]['geometry']['coordinates'] as List;
        final polyline = coords.map((c) => LatLng(c[1], c[0])).toList();

        setState(() {
          polylinePoints = polyline;
          duration = features[0]['properties']['summary']['duration'];
          distance = features[0]['properties']['summary']['distance'];
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

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  @override
  Widget build(BuildContext context) {
    final durationMin = duration != null ? (duration! / 60).round() : null;
    final distanceKm = distance != null ? (distance! / 1000).toStringAsFixed(1) : null;

    return Scaffold(
      appBar: AppBar(title: const Text("Маршрут поїздки")),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.trip.origin.lat, widget.trip.origin.lng),
              initialZoom: 7,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.pojikhaly_razom',
                //backgroundColor: const Color(0xFFE8F8F5), // світлий бірюзовий фон
              ),
              if (polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // ✅ темніший контур маршруту
                    Polyline(
                      points: polylinePoints,
                      strokeWidth: 7, // трохи товстіший
                      color: const Color(0xFF009688), // темно-бірюзовий контур
                    ),
                    // ✅ основна бірюзова лінія маршруту
                    Polyline(
                      points: polylinePoints,
                      strokeWidth: 5, // трохи тонший
                      color: const Color(0xFF00796B), // бірюзовий маршрут
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.trip.origin.lat, widget.trip.origin.lng),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on,
                        color: Colors.green, size: 40),
                  ),
                  Marker(
                    point: LatLng(widget.trip.destination.lat, widget.trip.destination.lng),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on,
                        color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          if (durationMin != null && distanceKm != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
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
                child: Text(
                  "Час: $durationMin хв • Відстань: $distanceKm км",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
