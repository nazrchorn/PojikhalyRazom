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
  final String status; // 'active', 'completed', 'cancelled'
  final bool allowChildren;
  final bool allowPets;
  final bool womenOnly;
  final String? cancelledBy; // хто скасував поїздку (driverId або passengerId)
  final String? cancellationReason; // причина скасування
  final DateTime? cancelledAt; // коли скасована
  final DateTime? completedAt; // коли завершена
  final int? estimatedDurationMinutes; // запланована тривалість маршруту

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
    this.status = 'active',
    this.allowChildren = false,
    this.allowPets = false,
    this.womenOnly = false,
    this.cancelledBy,
    this.cancellationReason,
    this.cancelledAt,
    this.completedAt,
    this.estimatedDurationMinutes,
  });

  DateTime getPlannedArrivalTime() {
    final minutes = estimatedDurationMinutes ?? 0;
    if (minutes <= 0) {
      return departureTime;
    }
    return departureTime.add(Duration(minutes: minutes));
  }

  bool isCompletedByTime(DateTime now) {
    return now.isAfter(getPlannedArrivalTime());
  }

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
      'status': status,
      'cancelledBy': cancelledBy,
      'cancellationReason': cancellationReason,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'estimatedDurationMinutes': estimatedDurationMinutes,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map, String id) {
    // Функція для безпечної конвертації дати
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) {
        return date.toDate(); // Якщо це Timestamp (Firebase)
      }
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
      status: map['status'] ?? 'active',
      stops: (map['stops'] as List<dynamic>?)
          ?.map((s) => Location.fromMap(s))
          .toList() ??
          [],
      allowChildren: map['allowChildren'] ?? true,
      allowPets: map['allowPets'] ?? false,
      womenOnly: map['womenOnly'] ?? false,
      cancelledBy: map['cancelledBy'],
      cancellationReason: map['cancellationReason'],
      cancelledAt: map['cancelledAt'] != null ? parseDate(map['cancelledAt']) : null,
      completedAt: map['completedAt'] != null ? parseDate(map['completedAt']) : null,
      estimatedDurationMinutes: (map['estimatedDurationMinutes'] as num?)?.toInt(),
    );
  }
}
