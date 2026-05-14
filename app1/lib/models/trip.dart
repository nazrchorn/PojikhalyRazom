import 'location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String driverId;
  final Location origin;
  final Location destination;
  final DateTime departureTime;
  final int availableSeats;
  final double pricePerSeat;
  final List<String> passengers;
  final DateTime createdAt;
  final List<Location> stops;
  final List<String> routeCities;
  // ✅ нові фільтри
  final bool allowChildren;
  final bool allowPets;
  final bool womenOnly;

  Trip({
    required this.id,
    required this.driverId,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.availableSeats,
    required this.pricePerSeat,
    required this.passengers,
    required this.createdAt,
    required this.stops,
    required this.routeCities,
    this.allowChildren = true,
    this.allowPets = false,
    this.womenOnly = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'origin': origin.toMap(),
      'destination': destination.toMap(),
      'departureTime': departureTime.toIso8601String(),
      'availableSeats': availableSeats,
      'pricePerSeat': pricePerSeat,
      'passengers': passengers,
      'createdAt': createdAt.toIso8601String(),
      'stops': stops.map((s) => s.toMap()).toList(),
      'routeCities': routeCities,
      'allowChildren': allowChildren,
      'allowPets': allowPets,
      'womenOnly': womenOnly,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map, String id) {
    // Функція для безпечної конвертації дати
    DateTime parseDate(dynamic date) {
      if (date is Timestamp)
        return date.toDate(); // Якщо це Timestamp (Firebase)
      if (date is String) return DateTime.parse(date); // Якщо це String
      return DateTime.now(); // Фолбек
    }

    return Trip(
      id: id,
      driverId: map['driverId'] ?? '',
      origin: Location.fromMap(map['origin']),
      destination: Location.fromMap(map['destination']),
      departureTime: parseDate(map['departureTime']),
      routeCities: List<String>.from(map['routeCities'] ?? []),
      availableSeats: map['availableSeats'] ?? 0,
      pricePerSeat: (map['pricePerSeat'] as num?)?.toDouble() ?? 0.0,
      passengers: List<String>.from(map['passengers'] ?? []),
      createdAt: parseDate(map['createdAt']),

      stops: (map['stops'] as List<dynamic>?)
          ?.map((s) => Location.fromMap(s))
          .toList() ??
          [],
      allowChildren: map['allowChildren'] ?? true,
      allowPets: map['allowPets'] ?? false,
      womenOnly: map['womenOnly'] ?? false,
    );
  }
}
