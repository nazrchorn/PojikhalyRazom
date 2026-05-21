import 'package:cloud_firestore/cloud_firestore.dart';

class BookingRequest {
  final String id;
  final String tripId;
  final String driverId;
  final String passengerId;
  final String? fromCity;
  final String? toCity;
  final String status; // pending | confirmed | rejected | cancelled
  final double? requestedPrice;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? dropoffAddress;
  final DateTime createdAt;
  final DateTime? updatedByDriverAt;
  final DateTime? passengerAcknowledgedAt;
  final DateTime? respondedAt;
  final String? respondedBy;

  const BookingRequest({
    required this.id,
    required this.tripId,
    required this.driverId,
    required this.passengerId,
    required this.status,
    required this.createdAt,
    this.requestedPrice,
    this.fromCity,
    this.toCity,
    this.pickupLat,
    this.pickupLng,
    this.pickupAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.dropoffAddress,
    this.updatedByDriverAt,
    this.passengerAcknowledgedAt,
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
      requestedPrice: (map['requestedPrice'] as num?)?.toDouble(),
      pickupLat: (map['pickupLat'] as num?)?.toDouble(),
      pickupLng: (map['pickupLng'] as num?)?.toDouble(),
      pickupAddress: map['pickupAddress'],
      dropoffLat: (map['dropoffLat'] as num?)?.toDouble(),
      dropoffLng: (map['dropoffLng'] as num?)?.toDouble(),
      dropoffAddress: map['dropoffAddress'],
      createdAt: parse(map['createdAt']),
      updatedByDriverAt: map['updatedByDriverAt'] != null ? parse(map['updatedByDriverAt']) : null,
      passengerAcknowledgedAt:
          map['passengerAcknowledgedAt'] != null ? parse(map['passengerAcknowledgedAt']) : null,
      respondedAt: map['respondedAt'] != null ? parse(map['respondedAt']) : null,
      respondedBy: map['respondedBy'],
    );
  }
}

