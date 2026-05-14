class Location {
  final String city;
  final String countryCode; // ISO‑3166 код, напр. "UA"
  final double lat;
  final double lng;

  Location({
    required this.city,
    required this.countryCode,
    required this.lat,
    required this.lng,
  });

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      city: map['city'] ?? '-',
      countryCode: map['countryCode'] ?? 'UA', // за замовчуванням Україна
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'city': city,
      'countryCode': countryCode,
      'lat': lat,
      'lng': lng,
    };
  }
}
