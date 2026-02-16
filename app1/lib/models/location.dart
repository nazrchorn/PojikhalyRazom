class Location {
  final String city;
  final double lat;
  final double lng;

  Location({required this.city, required this.lat, required this.lng});

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      city: map['city'],
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'city': city,
      'lat': lat,
      'lng': lng,
    };
  }
}
