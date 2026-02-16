import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String tripId;
  final String passengerId;
  final int seatsBooked;
  final String status; // pending, confirmed, cancelled
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.tripId,
    required this.passengerId,
    required this.seatsBooked,
    required this.status,
    required this.createdAt,
  });

  factory Booking.fromMap(String id, Map<String, dynamic> map) {
    return Booking(
      id: id,
      tripId: map['tripId'],
      passengerId: map['passengerId'],
      seatsBooked: map['seatsBooked'],
      status: map['status'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'passengerId': passengerId,
      'seatsBooked': seatsBooked,
      'status': status,
      'createdAt': createdAt,
    };
  }
}