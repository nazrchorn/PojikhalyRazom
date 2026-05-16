import 'package:cloud_firestore/cloud_firestore.dart';

class BookingRequest {
  final String id;
  final String tripId;
  final String driverId;
  final String passengerId;
  final String? fromCity;
  final String? toCity;
  final String status; // pending | confirmed | rejected | cancelled
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? respondedBy;

  const BookingRequest({
    required this.id,
    required this.tripId,
    required this.driverId,
    required this.passengerId,
    required this.status,
    required this.createdAt,
    this.fromCity,
    this.toCity,
    this.respondedAt,
    this.respondedBy,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';

  factory BookingRequest.fromMap(String id, Map<String, dynamic> map) {
    DateTime parse(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return BookingRequest(
      id: id,
      tripId: map['tripId'] ?? '',
      driverId: map['driverId'] ?? '',
      passengerId: map['passengerId'] ?? '',
      fromCity: map['fromCity'],
      toCity: map['toCity'],
      status: map['status'] ?? 'pending',
      createdAt: parse(map['createdAt']),
      respondedAt: map['respondedAt'] != null ? parse(map['respondedAt']) : null,
      respondedBy: map['respondedBy'],
    );
  }
}

