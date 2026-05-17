import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class MapService {
  // Nominatim OpenStreetMap API (безкоштовний, не потребує ключ)
  static const String _nominatimBaseUrl =
      'https://nominatim.openstreetmap.org/search';

  // User-Agent для Nominatim (обов'язковий для стабільної роботи)
  static const String _userAgent = 'Pojikhaly_Razom_Student_Project';

  // ── Local city cache ──────────────────────────────────────────────────────
  static List<Map<String, dynamic>>? _localCities;

  static Future<List<Map<String, dynamic>>> _getLocalCities() async {
    if (_localCities != null) return _localCities!;
    try {
      final raw = await rootBundle.loadString('assets/ukraine_cities.json');
      _localCities = List<Map<String, dynamic>>.from(
          (json.decode(raw) as List).cast<Map<String, dynamic>>());
    } catch (_) {
      _localCities = [];
    }
    return _localCities!;
  }

  // ── Fuzzy helpers ─────────────────────────────────────────────────────────

  /// Levenshtein distance (case-insensitive)
  static int _levenshtein(String a, String b) {
    final la = a.toLowerCase(), lb = b.toLowerCase();
    if (la == lb) return 0;
    if (la.isEmpty) return lb.length;
    if (lb.isEmpty) return la.length;
    final rows = List<List<int>>.generate(
        la.length + 1, (i) => List<int>.filled(lb.length + 1, 0));
    for (int i = 0; i <= la.length; i++) rows[i][0] = i;
    for (int j = 0; j <= lb.length; j++) rows[0][j] = j;
    for (int i = 1; i <= la.length; i++) {
      for (int j = 1; j <= lb.length; j++) {
        final cost = la[i - 1] == lb[j - 1] ? 0 : 1;
        rows[i][j] = [
          rows[i - 1][j] + 1,
          rows[i][j - 1] + 1,
          rows[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return rows[la.length][lb.length];
  }

  /// Returns max allowed edit distance based on query length.
  static int _maxErrors(int len) {
    if (len <= 3) return 0;
    if (len <= 5) return 1;
    if (len <= 8) return 2;
    return 3;
  }

  /// Search local city list with fuzzy matching.
  static Future<List<Map<String, dynamic>>> _fuzzyLocalSearch(
      String query) async {
    if (query.trim().length < 2) return [];
    final cities = await _getLocalCities();
    final q = query.trim().toLowerCase();
    final maxErr = _maxErrors(q.length);
    final scored = <MapEntry<int, Map<String, dynamic>>>[];
    for (final c in cities) {
      final name = (c['name'] as String).toLowerCase();
      // Exact prefix → top priority
      if (name.startsWith(q)) {
        scored.add(MapEntry(0, c));
        continue;
      }
      // Contains → second priority
      if (name.contains(q)) {
        scored.add(MapEntry(1, c));
        continue;
      }
      // Fuzzy: compare against prefix of same length
      final prefix = name.length >= q.length ? name.substring(0, q.length) : name;
      final dist = _levenshtein(q, prefix);
      if (dist <= maxErr) {
        scored.add(MapEntry(dist + 2, c));
      }
    }
    scored.sort((a, b) => a.key.compareTo(b.key));
    return scored.map((e) => e.value).toList();
  }

  // ── City name extraction from Nominatim address ──────────────────────────

  static String _extractCityName(
      Map<String, dynamic> address, String displayName) {
    return address['city'] ??
        address['town'] ??
        address['municipality'] ??
        address['village'] ??
        address['hamlet'] ??
        address['suburb'] ??
        address['county'] ??
        address['district'] ??
        displayName.split(',').first.trim();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Instant local-only search (no network) — for immediate display while typing.
  static Future<List<Map<String, dynamic>>> searchLocalOnly(String query) =>
      _fuzzyLocalSearch(query);

  /// Combined search: local fuzzy first, then Nominatim.
  /// Used by CitySearchScreen.
  Future<List<Map<String, dynamic>>> searchAddresses(
    String query, {
    String countryCode = 'ua',
    String language = 'uk',
    int limit = 10,
  }) async {
    if (query.trim().length < 2) return [];

    // Run local fuzzy + Nominatim in parallel
    final localFuture = _fuzzyLocalSearch(query);
    final apiResults = await _fetchNominatim(query,
        countryCode: countryCode, language: language, limit: limit);

    final localMatches = await localFuture;

    // Build final list: local fuzzy results converted to display format first,
    // then Nominatim results (de-duplicated by city name)
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final c in localMatches) {
      final name = c['name'] as String;
      if (seen.add(name.toLowerCase())) {
        result.add({
          'properties': {
            'locality': name,
            'label': name,
          },
          'geometry': {
            'coordinates': [c['lng'] as double, c['lat'] as double],
          },
        });
      }
    }

    for (final item in apiResults) {
      final props = item['properties'] as Map<String, dynamic>;
      final locality = (props['locality'] as String? ?? '').toLowerCase();
      if (locality.isNotEmpty && seen.add(locality)) {
        result.add(item);
      }
    }

    return result.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchNominatim(
    String query, {
    required String countryCode,
    required String language,
    required int limit,
  }) async {
    final url = '$_nominatimBaseUrl?'
        'q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=$limit'
        '&countrycodes=$countryCode'
        '&accept-language=$language';
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final data = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return data.map((item) {
        final address = item['address'] as Map<String, dynamic>;
        final displayName = item['display_name'] as String;
        final cityName = _extractCityName(address, displayName);
        return {
          'properties': {
            'locality': cityName,
            'label': displayName,
          },
          'geometry': {
            'coordinates': [
              double.parse(item['lon'].toString()),
              double.parse(item['lat'].toString()),
            ]
          }
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Departure search — combined fuzzy + Nominatim
  Future<List<Map<String, dynamic>>> searchAddressesForDeparture(
      String query) async {
    if (query.trim().length < 2) return [];
    final localFuture = _fuzzyLocalSearch(query);
    final apiResults = await _fetchNominatimRaw(query);
    final localMatches = await localFuture;
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final c in localMatches) {
      final name = c['name'] as String;
      if (seen.add(name.toLowerCase())) {
        result.add({
          'city': name,
          'country': 'Україна',
          'address': name,
          'lat': (c['lat'] as num).toDouble(),
          'lng': (c['lng'] as num).toDouble(),
        });
      }
    }
    for (final item in apiResults) {
      final name = (item['city'] as String).toLowerCase();
      if (seen.add(name)) result.add(item);
    }
    return result.take(10).toList();
  }

  /// Arrival search — combined fuzzy + Nominatim
  Future<List<Map<String, dynamic>>> searchAddressesForArrival(
      String query) async {
    if (query.trim().length < 2) return [];
    final localFuture = _fuzzyLocalSearch(query);
    final apiResults = await _fetchNominatimRaw(query);
    final localMatches = await localFuture;
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final c in localMatches) {
      final name = c['name'] as String;
      if (seen.add(name.toLowerCase())) {
        result.add({
          'city': name,
          'address': name,
          'lat': (c['lat'] as num).toDouble(),
          'lng': (c['lng'] as num).toDouble(),
        });
      }
    }
    for (final item in apiResults) {
      final name = (item['city'] as String).toLowerCase();
      if (seen.add(name)) result.add(item);
    }
    return result.take(10).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchNominatimRaw(String query) async {
    final url = '$_nominatimBaseUrl?'
        'q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=10'
        '&countrycodes=ua'
        '&accept-language=uk';
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final data = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return data.map((item) {
        final address = item['address'] as Map<String, dynamic>;
        final displayName = item['display_name'] as String;
        final cityName = _extractCityName(address, displayName);
        return {
          'city': cityName,
          'country': address['country'] ?? 'Україна',
          'address': displayName,
          'lat': double.parse(item['lat'].toString()),
          'lng': double.parse(item['lon'].toString()),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

