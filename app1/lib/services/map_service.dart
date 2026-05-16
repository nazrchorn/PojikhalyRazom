import 'dart:convert';
import 'package:http/http.dart' as http;

class MapService {
  // Nominatim OpenStreetMap API (безкоштовний, не потребує ключ)
  static const String _nominatimBaseUrl =
      'https://nominatim.openstreetmap.org/search';

  // User-Agent для Nominatim (обов'язковий для стабільної роботи)
  static const String _userAgent = 'Pojikhaly_Razom_Student_Project';

  /// Пошук адрес через Nominatim
  /// Повертає список адрес у форматі, сумісному з UI
  Future<List<Map<String, dynamic>>> searchAddresses(
    String query, {
    String countryCode = 'ua',
    String language = 'uk',
    int limit = 10,
  }) async {
    if (query.trim().length < 2) {
      return [];
    }

    final String url = '$_nominatimBaseUrl?'
        'q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=$limit'
        '&countrycodes=$countryCode'
        '&accept-language=$language';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _userAgent,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

        return data.map((item) {
          final address = item['address'] as Map<String, dynamic>;
          final String cityName = address['city'] ??
              address['town'] ??
              address['village'] ??
              (item['display_name'] as String).split(',')[0];

          return {
            'properties': {
              'locality': cityName,
              'label': item['display_name'] as String,
            },
            'geometry': {
              'coordinates': [
                double.parse(item['lon'].toString()),
                double.parse(item['lat'].toString()),
              ]
            }
          };
        }).toList();
      } else {
        throw Exception('Помилка сервера: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Пошук адрес та повернення у форматі для DepartureSearchScreen
  Future<List<Map<String, dynamic>>> searchAddressesForDeparture(
      String query) async {
    if (query.trim().length < 2) {
      return [];
    }

    final String url = '$_nominatimBaseUrl?'
        'q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=10'
        '&countrycodes=ua'
        '&accept-language=uk';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

        return data.map((item) {
          final addr = item['address'] as Map<String, dynamic>;
          return {
            'city': addr['city'] ?? addr['town'] ?? addr['village'] ?? 'Невідомо',
            'country': addr['country'] ?? 'Україна',
            'address': item['display_name'] as String,
            'lat': double.parse(item['lat'].toString()),
            'lng': double.parse(item['lon'].toString()),
          };
        }).toList();
      } else {
        throw Exception('Помилка сервера: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Пошук адрес та повернення у форматі для ArrivalSearchScreen
  Future<List<Map<String, dynamic>>> searchAddressesForArrival(String query) async {
    if (query.trim().length < 2) {
      return [];
    }

    final String url = '$_nominatimBaseUrl?'
        'q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=10'
        '&countrycodes=ua'
        '&accept-language=uk';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

        return data.map((item) {
          final addr = item['address'] as Map<String, dynamic>;
          final String city =
              addr['city'] ?? addr['town'] ?? addr['village'] ?? 'Невідомо';

          return {
            'city': city,
            'address': item['display_name'] as String,
            'lat': double.parse(item['lat'].toString()),
            'lng': double.parse(item['lon'].toString()),
          };
        }).toList();
      } else {
        throw Exception('Помилка сервера: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}

