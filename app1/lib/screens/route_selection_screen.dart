import 'package:app1/screens/stops_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/route_service.dart';

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
  final RouteService _routeService = RouteService();

  static const Color _primaryTurquoise = Color(0xFF1F6F66);

  static const List<Color> _routeColors = [
    Color(0xFF1F6F66),
    Color(0xFF1565C0),
    Color(0xFFE65100),
  ];

  List<Map<String, dynamic>> _routes = [];
  int _selectedRouteIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final originLatLng = LatLng(
      (widget.origin['lat'] as num).toDouble(),
      (widget.origin['lng'] as num).toDouble(),
    );
    final destLatLng = LatLng(
      (widget.destination['lat'] as num).toDouble(),
      (widget.destination['lng'] as num).toDouble(),
    );

    // Step 1: load single route fast so map is never empty
    Map<String, dynamic>? single;
    try {
      single = await _routeService.fetchRouteWithWaypoints(
        waypoints: [originLatLng, destLatLng],
        apiKey: widget.apiKey,
      );
    } catch (_) {}

    if (!mounted) return;

    if (single == null) {
      // Keep loading — just retry silently after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _loadRoutes();
      });
      return;
    }

    setState(() {
      _routes = [single!];
      _selectedRouteIndex = 0;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitRoute(_routes[0]);
    });

    // Step 2: try to get alternatives silently in background
    try {
      final alts = await _routeService.fetchAlternativeRoutes(
        origin: widget.origin,
        destination: widget.destination,
        apiKey: widget.apiKey,
        targetCount: 3,
      );
      if (mounted && alts.length > 1) {
        setState(() {
          _routes = alts;
          _selectedRouteIndex = 0;
        });
      }
    } catch (_) {
      // Silently keep the single route already shown
    }
  }

  void _fitRoute(Map<String, dynamic> route) {
    final points = route['polyline'] as List<LatLng>;
    if (points.isEmpty) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    try {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.fromLTRB(40, 80, 40, 280),
      ));
    } catch (_) {}
  }

  void _selectRoute(int idx) {
    setState(() => _selectedRouteIndex = idx);
    _fitRoute(_routes[idx]);
  }

  void _confirm() {
    if (_routes.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StopSelectionScreen(
          origin: widget.origin,
          destination: widget.destination,
          selectedRoute: _routes[_selectedRouteIndex],
          apiKey: widget.apiKey,
        ),
      ),
    );
  }

  String _fmtDuration(double s) {
    final m = (s / 60).round();
    if (m < 60) return '$m хв';
    final h = m ~/ 60, rem = m % 60;
    return rem == 0 ? '$h год' : '$h год $rem хв';
  }

  String _fmtDistance(double m) =>
      m < 1000 ? '${m.round()} м' : '${(m / 1000).toStringAsFixed(1)} км';

  @override
  Widget build(BuildContext context) {
    final originPt = LatLng(
      (widget.origin['lat'] as num).toDouble(),
      (widget.origin['lng'] as num).toDouble(),
    );
    final destPt = LatLng(
      (widget.destination['lat'] as num).toDouble(),
      (widget.destination['lng'] as num).toDouble(),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Вибір маршруту',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Theme.of(context).appBarTheme.surfaceTintColor,
        elevation: 0,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Stack(
        children: [
          // MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: originPt,
              initialZoom: 7,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.pojikhaly_razom',
              ),
              if (_routes.isNotEmpty)
                PolylineLayer(
                  polylines: _routes.asMap().entries.map((e) {
                    final selected = e.key == _selectedRouteIndex;
                    final color = _routeColors[e.key % _routeColors.length];
                    return Polyline(
                      points: e.value['polyline'] as List<LatLng>,
                      strokeWidth: selected ? 5 : 3,
                      color: selected ? color : color.withValues(alpha: 0.35),
                    );
                  }).toList(),
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: originPt,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on,
                        color: Color(0xFF1F6F66), size: 40),
                  ),
                  Marker(
                    point: destPt,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on,
                        color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),

          // LOADING spinner (small, non-blocking)
          if (_isLoading)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(24))),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1F6F66)),
                        ),
                        SizedBox(width: 10),
                        Text('Завантаження маршруту…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),


          // ROUTE LIST + CONFIRM
          if (!_isLoading && _routes.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _Sheet(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_routes.length > 1)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Оберіть маршрут',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    if (_routes.length > 1)
                      ..._routes.asMap().entries.map((e) {
                        final idx = e.key;
                        final r = e.value;
                        final selected = idx == _selectedRouteIndex;
                        final color =
                            _routeColors[idx % _routeColors.length];
                        return _RouteCard(
                          label: idx == 0
                              ? 'Найшвидший'
                              : idx == 1
                                  ? 'Альтернативний'
                                  : 'Ще варіант',
                          duration:
                              _fmtDuration((r['duration'] as num).toDouble()),
                          distance:
                              _fmtDistance((r['distance'] as num).toDouble()),
                          color: color,
                          selected: selected,
                          onTap: () => _selectRoute(idx),
                        );
                      }),
                    if (_routes.length == 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Row(
                          children: [
                            const Icon(Icons.route,
                                color: _primaryTurquoise, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              '${_fmtDuration((_routes[0]['duration'] as num).toDouble())} • ${_fmtDistance((_routes[0]['distance'] as num).toDouble())}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryTurquoise,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Text('Підтвердити маршрут',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
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

class _Sheet extends StatelessWidget {
  final Widget child;
  const _Sheet({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(top: false, child: child),
      );
}

class _RouteCard extends StatelessWidget {
  final String label;
  final String duration;
  final String distance;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RouteCard({
    required this.label,
    required this.duration,
    required this.distance,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? color : Colors.grey.shade200,
                width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 34,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? color : Colors.black87)),
                    Text('$duration • $distance',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? color : Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      );
}
