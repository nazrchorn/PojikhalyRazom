import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/trip.dart';
import '../services/route_service.dart';

class TripDetailsMapScreen extends StatefulWidget {
  final Trip trip;
  final String apiKey;
  final List<String> visibleRouteCities;
  final String? highlightedFromCity;
  final String? highlightedToCity;

  const TripDetailsMapScreen({
    super.key,
    required this.trip,
    required this.apiKey,
    required this.visibleRouteCities,
    this.highlightedFromCity,
    this.highlightedToCity,
  });

  @override
  State<TripDetailsMapScreen> createState() => _TripDetailsMapScreenState();
}

class _TripDetailsMapScreenState extends State<TripDetailsMapScreen> {
  final MapController _mapController = MapController();
  final RouteService _routeService = RouteService();
  List<LatLng> polylinePoints = [];
  List<LatLng> segmentPolylinePoints = [];
  double? duration;
  double? distance;

  String _normalizeCity(String city) => city.split(',').first.trim().toLowerCase();

  bool _isVisibleRouteCity(String city) {
    final normalized = _normalizeCity(city);
    return widget.visibleRouteCities.any((c) => _normalizeCity(c) == normalized);
  }

  LatLng? _resolveCityPoint(String? city) {
    if (city == null || city.trim().isEmpty) {
      return null;
    }
    final normalized = _normalizeCity(city);
    final candidates = [widget.trip.origin, ...widget.trip.stops, widget.trip.destination];
    for (final point in candidates) {
      if (_normalizeCity(point.city) == normalized) {
        return LatLng(point.lat, point.lng);
      }
    }
    return null;
  }

  List<LatLng> _buildVisibleRoutePoints() {
    final ordered = [widget.trip.origin, ...widget.trip.stops, widget.trip.destination];
    final points = <LatLng>[];
    for (int i = 0; i < ordered.length; i++) {
      final city = ordered[i].city;
      final include = i == 0 || i == ordered.length - 1 || _isVisibleRouteCity(city);
      if (!include) continue;
      points.add(LatLng(ordered[i].lat, ordered[i].lng));
    }
    return points;
  }

  Future<void> _fetchRoute() async {
    try {
      final viaPoints = _buildVisibleRoutePoints();
      final routeData = viaPoints.length >= 2
          ? await _routeService.fetchRouteWithWaypoints(
              waypoints: viaPoints,
              apiKey: widget.apiKey,
            )
          : await _routeService.fetchRouteForTrip(
              startLat: widget.trip.origin.lat,
              startLng: widget.trip.origin.lng,
              endLat: widget.trip.destination.lat,
              endLng: widget.trip.destination.lng,
              apiKey: widget.apiKey,
            );

      if (!mounted) return;

      if (routeData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Маршрутів не знайдено")),
        );
        return;
      }

      setState(() {
        polylinePoints = List<LatLng>.from(routeData['polyline'] as List<LatLng>);
        duration = (routeData['duration'] as num?)?.toDouble();
        distance = (routeData['distance'] as num?)?.toDouble();
      });

      final fromPoint = _resolveCityPoint(widget.highlightedFromCity);
      final toPoint = _resolveCityPoint(widget.highlightedToCity);
      if (fromPoint != null && toPoint != null) {
        final segmentRoute = await _routeService.fetchRouteForTrip(
          startLat: fromPoint.latitude,
          startLng: fromPoint.longitude,
          endLat: toPoint.latitude,
          endLng: toPoint.longitude,
          apiKey: widget.apiKey,
        );

        if (!mounted) return;
        if (segmentRoute != null) {
          setState(() {
            segmentPolylinePoints = List<LatLng>.from(segmentRoute['polyline'] as List<LatLng>);
          });
        }
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
    final fromPoint = _resolveCityPoint(widget.highlightedFromCity);
    final toPoint = _resolveCityPoint(widget.highlightedToCity);
    final visibleStops = widget.trip.stops.where((stop) => _isVisibleRouteCity(stop.city)).toList();

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
              if (segmentPolylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: segmentPolylinePoints,
                      strokeWidth: 4,
                      color: const Color(0xFF009688),
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
                  ...visibleStops.map((stop) => Marker(
                        point: LatLng(stop.lat, stop.lng),
                        width: 34,
                        height: 34,
                        child: const Icon(Icons.trip_origin, color: Color(0xFF4DB6AC), size: 20),
                      )),
                  if (fromPoint != null)
                    Marker(
                      point: fromPoint,
                      width: 38,
                      height: 38,
                      child: const Icon(Icons.flag_circle, color: Colors.blue, size: 30),
                    ),
                  if (toPoint != null)
                    Marker(
                      point: toPoint,
                      width: 38,
                      height: 38,
                      child: const Icon(Icons.flag_circle, color: Color(0xFF009688), size: 30),
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
                  color: Colors.white.withValues(alpha: 0.9),
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
