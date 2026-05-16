import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference tripsCollection =
  FirebaseFirestore.instance.collection('trips');

  /// Створення нової поїздки
  Future<void> createTrip(Trip trip) async {
    await tripsCollection.add(trip.toMap());
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
          return snapshot.docs
              .map((doc) => Trip.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
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
  }

  Future<void> cancelTrip({
    required String tripId,
    required String cancelledBy,
  }) async {
    await _firestore.collection('trips').doc(tripId).update({
      'status': 'cancelled',
      'cancelledBy': cancelledBy,
      'cancelledAt': DateTime.now(),
    });
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

