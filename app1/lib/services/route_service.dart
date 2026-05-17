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
    int targetCount = 3,
  }) async {
    final uri = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car/geojson',
    );

    final body = json.encode(<String, dynamic>{
      'coordinates': [
        <double>[
          (origin['lng'] as num).toDouble(),
          (origin['lat'] as num).toDouble(),
        ],
        <double>[
          (destination['lng'] as num).toDouble(),
          (destination['lat'] as num).toDouble(),
        ],
      ],
      'alternative_routes': <String, dynamic>{
        'target_count': targetCount.clamp(2, 3),
        'weight_factor': 1.4,
        'share_factor': 0.6,
      },
      'instructions': false,
    });

    final response = await http
        .post(
          uri,
          headers: <String, String>{
            'Authorization': apiKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json, application/geo+json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Маршрутний сервіс недоступний (HTTP ${response.statusCode}). '
        'Перевірте з\'єднання або спробуйте пізніше.',
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      throw Exception('Сервіс не повернув маршрутів. Спробуйте ще раз.');
    }

    final result = <Map<String, dynamic>>[];
    for (final dynamic feature in features) {
      try {
        final map = feature as Map<String, dynamic>;
        final coords = map['geometry']['coordinates'] as List<dynamic>;
        final polyline = coords
            .map((dynamic c) => LatLng(
                  ((c as List<dynamic>)[1] as num).toDouble(),
                  (c[0] as num).toDouble(),
                ))
            .toList();
        final summary = map['properties']['summary'] as Map<String, dynamic>;
        result.add(<String, dynamic>{
          'polyline': polyline,
          'geometry': map['geometry'],
          'duration': (summary['duration'] as num).toDouble(),
          'distance': (summary['distance'] as num).toDouble(),
        });
      } catch (_) {
        // Skip malformed feature, but don't crash the whole call
      }
    }

    if (result.isEmpty) {
      throw Exception('Не вдалося розпарсити маршрути. Спробуйте ще раз.');
    }

    return result;
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

