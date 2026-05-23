import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../models/trip.dart';
import 'rating_service.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RatingService _ratingService = RatingService();
  final CollectionReference tripsCollection =
  FirebaseFirestore.instance.collection('trips');

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  /// Створення нової поїздки
  Future<void> createTrip(Trip trip) async {
    final conflict = await validateDriverScheduleForNewTrip(trip);
    if (conflict != null) {
      throw StateError(conflict);
    }
    await tripsCollection.add(trip.toMap());
  }

  Future<String?> validateDriverScheduleForNewTrip(Trip candidate) async {
    final snapshot = await tripsCollection
        .where('driverId', isEqualTo: candidate.driverId)
        .get();

    final existingTrips = snapshot.docs
        .map((doc) => Trip.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((trip) => trip.status != 'cancelled' && trip.id != candidate.id)
        .toList();

    final candidateArrival = _plannedArrival(candidate);

    for (final trip in existingTrips) {
      final existingArrival = _plannedArrival(trip);
      final hasOverlap =
          candidate.departureTime.isBefore(existingArrival) && candidateArrival.isAfter(trip.departureTime);
      if (!hasOverlap) continue;

      return 'Конфлікт у розкладі: нова поїздка перетинається в часі з ${trip.origin.city} -> ${trip.destination.city} (${_formatDateTime(trip.departureTime)}).';
    }

    final timeline = <Trip>[...existingTrips, candidate]
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));

    for (int i = 0; i < timeline.length - 1; i++) {
      final prev = timeline[i];
      final next = timeline[i + 1];
      final touchesCandidate = prev.id == candidate.id || next.id == candidate.id;
      if (!touchesCandidate) {
        continue;
      }

      final prevArrival = _plannedArrival(prev);
      final transferMinutes = _estimateTransferMinutes(prev.destination.lat, prev.destination.lng, next.origin.lat, next.origin.lng);
      final availableGap = next.departureTime.difference(prevArrival).inMinutes;

      if (availableGap < transferMinutes) {
        return 'Недостатньо часу між рейсами: після ${prev.origin.city} -> ${prev.destination.city} треба дістатися до ${next.origin.city}. Потрібно щонайменше $transferMinutes хв.';
      }
    }

    return null;
  }

  DateTime _plannedArrival(Trip trip) {
    if (trip.estimatedDurationMinutes != null && trip.estimatedDurationMinutes! > 0) {
      return trip.departureTime.add(Duration(minutes: trip.estimatedDurationMinutes!));
    }
    final fallbackMinutes = _estimateTransferMinutes(trip.origin.lat, trip.origin.lng, trip.destination.lat, trip.destination.lng);
    return trip.departureTime.add(Duration(minutes: fallbackMinutes));
  }

  int _estimateTransferMinutes(double fromLat, double fromLng, double toLat, double toLng) {
    final distanceKm = _haversineKm(fromLat, fromLng, toLat, toLng);
    if (distanceKm <= 1.0) return 0;

    // Conservative average speed so repositioning is not underestimated.
    final minutes = (distanceKm / 70.0) * 60.0;
    return minutes.ceil();
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  String _formatDateTime(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd.$mm $hh:$min';
  }

  /// Отримати всі поїздки
  Stream<List<Trip>> getAllTrips() {
    return tripsCollection.orderBy("departureTime").snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Trip.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  /// Отримати поїздки за містами (Звідки → Куди)
  Stream<List<Trip>> getTripsByCities(String fromCity, String toCity) {
    return tripsCollection
        .where("origin.city", isEqualTo: fromCity)
        .where("destination.city", isEqualTo: toCity)
        .orderBy("departureTime")
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Trip.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  /// Потік поїздок, де користувач водій або пасажир
  Stream<List<Trip>> getUserTrips(String userId) {
    return tripsCollection
        .where(Filter.or(
          Filter('driverId', isEqualTo: userId),
          Filter('passengers', arrayContains: userId),
        ))
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final trips = snapshot.docs
              .map((doc) => Trip.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          // Keep persisted status in sync when planned arrival time has passed.
          for (final trip in trips) {
            if (trip.status == 'cancelled' || trip.status == 'completed') {
              continue;
            }
            if (!trip.isCompletedByTime(now)) {
              continue;
            }

            _firestore.collection('trips').doc(trip.id).update({
              'status': 'completed',
              'completedAt': FieldValue.serverTimestamp(),
            });
          }

          return trips;
        });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTrip(String tripId) {
    return _firestore.collection('trips').doc(tripId).snapshots();
  }

  Stream<Map<String, dynamic>?> watchTripData(String tripId) {
    return watchTrip(tripId).map((doc) => doc.data());
  }

  /// Отримати конкретну поїздку за ID
  Future<Trip?> getTripById(String id) async {
    final doc = await tripsCollection.doc(id).get();
    if (!doc.exists) return null;
    return Trip.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<int> getCompletedTripsCountForDriver(String driverId) async {
    final snapshot = await tripsCollection
        .where('driverId', isEqualTo: driverId)
        .get();

    final now = DateTime.now();
    return snapshot.docs
        .map((doc) => Trip.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((trip) =>
            trip.status != 'cancelled' &&
            (trip.status == 'completed' || trip.isCompletedByTime(now)))
        .length;
  }

  Future<void> bookSeat({
    required String tripId,
    required String userId,
    String? fromCity,
    String? toCity,
  }) async {
    final tripRef = _firestore.collection('trips').doc(tripId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(tripRef);
      final int seats = snap.data()?['availableSeats'] ?? 0;
      final List<dynamic> passengers = List<dynamic>.from(snap.data()?['passengers'] ?? <dynamic>[]);

      if (passengers.contains(userId) || seats <= 0) {
        throw StateError('Немає місць або користувач вже у поїздці');
      }

      tx.update(tripRef, {
        'availableSeats': seats - 1,
        'passengers': FieldValue.arrayUnion([userId]),
        if (fromCity != null && fromCity.isNotEmpty)
          'passengerSegments.$userId.fromCity': fromCity,
        if (toCity != null && toCity.isNotEmpty)
          'passengerSegments.$userId.toCity': toCity,
      });
    });
  }

  Future<void> cancelBooking({
    required String tripId,
    required String userId,
  }) async {
    final tripRef = _firestore.collection('trips').doc(tripId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(tripRef);
      final int seats = snap.data()?['availableSeats'] ?? 0;
      final List<dynamic> passengers = List<dynamic>.from(snap.data()?['passengers'] ?? <dynamic>[]);

      if (!passengers.contains(userId)) {
        return;
      }

      passengers.remove(userId);
      tx.update(tripRef, {
        'availableSeats': seats + 1,
        'passengers': passengers,
        'passengerSegments.$userId': FieldValue.delete(),
      });
    });

    try {
      await _ratingService.applyCancellationPenalty(
        userId: userId,
        points: 0.15,
        reason: 'passenger_cancelled_booking_direct',
        tripId: tripId,
      );
    } catch (_) {
      // Keep cancellation successful even if rating write fails.
    }
  }

  Future<void> cancelTrip({
    required String tripId,
    required String cancelledBy,
  }) async {
    final tripRef = _firestore.collection('trips').doc(tripId);
    final tripSnap = await tripRef.get();
    final data = tripSnap.data() ?? <String, dynamic>{};
    final driverId = data['driverId'] as String? ?? '';
    final departure = _parseDate(data['departureTime']);

    await tripRef.update({
      'status': 'cancelled',
      'cancelledBy': cancelledBy,
      'cancelledAt': DateTime.now(),
    });

    if (cancelledBy != driverId || cancelledBy.trim().isEmpty) {
      return;
    }

    double penalty = 0.30;
    if (departure != null) {
      final hoursBefore = departure.difference(DateTime.now()).inMinutes / 60.0;
      if (hoursBefore < 6) {
        penalty = 0.50;
      } else if (hoursBefore < 24) {
        penalty = 0.40;
      }
    }

    try {
      await _ratingService.applyCancellationPenalty(
        userId: cancelledBy,
        points: penalty,
        reason: 'driver_cancelled_trip',
        tripId: tripId,
      );
    } catch (_) {
      // Keep trip cancellation successful even if rating write fails.
    }
  }

  /// Додати пасажира до поїздки
  Future<void> addPassenger(String tripId, String userId) async {
    final tripRef = tripsCollection.doc(tripId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(tripRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      int availableSeats = data['availableSeats'];
      List passengers = List.from(data['passengers']);

      if (availableSeats > 0 && !passengers.contains(userId)) {
        passengers.add(userId);
        availableSeats--;

        transaction.update(tripRef, {
          'availableSeats': availableSeats,
          'passengers': passengers,
        });
      }
    });
  }
}

// Backward compatibility for old references.
class TripServices extends TripService {}

