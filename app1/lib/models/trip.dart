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
  });

  factory Trip.fromMap(String id, Map<String, dynamic> map) {
    return Trip(
      id: id,
      driverId: map['driverId'],
      origin: Location.fromMap(map['origin']),
      destination: Location.fromMap(map['destination']),
      departureTime: (map['departureTime'] as Timestamp).toDate(),
      availableSeats: map['availableSeats'],
      pricePerSeat: (map['pricePerSeat'] as num).toDouble(),
      passengers: List<String>.from(map['passengers']),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'origin': origin.toMap(),
      'destination': destination.toMap(),
      'departureTime': departureTime,
      'availableSeats': availableSeats,
      'pricePerSeat': pricePerSeat,
      'passengers': passengers,
      'createdAt': createdAt,
    };
  }
}