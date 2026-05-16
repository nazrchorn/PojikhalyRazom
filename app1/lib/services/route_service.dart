import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  Future<Map<String, dynamic>?> fetchRouteWithWaypoints({
    required List<LatLng> waypoints,
    required String apiKey,
  }) async {
    if (waypoints.length < 2) return null;

    final coordinates = waypoints
        .map((p) => <double>[p.longitude, p.latitude])
        .toList();

    final uri = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car/geojson',
    );

    final response = await http
        .post(
          uri,
          headers: <String, String>{
            'Authorization': apiKey,
            'Content-Type': 'application/json',
          },
          body: json.encode(<String, dynamic>{
            'coordinates': coordinates,
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      return null;
    }

    final feature = features.first as Map<String, dynamic>;
    final coords = feature['geometry']['coordinates'] as List<dynamic>;
    final polyline = coords
        .map((dynamic c) => LatLng(
              ((c as List<dynamic>)[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ))
        .toList();

    return {
      'polyline': polyline,
      'duration': feature['properties']['summary']['duration'],
      'distance': feature['properties']['summary']['distance'],
    };
  }

  Future<List<Map<String, dynamic>>> fetchAlternativeRoutes({
    required Map<String, dynamic> origin,
    required Map<String, dynamic> destination,
    required String apiKey,
  }) async {
    final start = '${origin['lng']},${origin['lat']}';
    final end = '${destination['lng']},${destination['lat']}';

    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car'
        '?api_key=$apiKey&start=$start&end=$end&alternative_routes=true';

    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return features.map((dynamic feature) {
      final map = feature as Map<String, dynamic>;
      final coords = map['geometry']['coordinates'] as List<dynamic>;
      final polyline = coords
          .map((dynamic c) => LatLng(
                ((c as List<dynamic>)[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();
      return {
        'polyline': polyline,
        'geometry': map['geometry'],
        'duration': map['properties']['summary']['duration'],
        'distance': map['properties']['summary']['distance'],
      };
    }).toList();
  }

  Future<Map<String, dynamic>?> fetchRouteForTrip({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String apiKey,
  }) async {
    final start = '$startLng,$startLat';
    final end = '$endLng,$endLat';

    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car'
        '?api_key=$apiKey&start=$start&end=$end';

    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      return null;
    }

    final feature = features.first as Map<String, dynamic>;
    final coords = feature['geometry']['coordinates'] as List<dynamic>;
    final polyline = coords
        .map((dynamic c) => LatLng(
              ((c as List<dynamic>)[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ))
        .toList();

    return {
      'polyline': polyline,
      'duration': feature['properties']['summary']['duration'],
      'distance': feature['properties']['summary']['distance'],
    };
  }
}


