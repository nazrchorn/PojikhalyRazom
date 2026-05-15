import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';

class TripServices {
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

  /// Отримати конкретну поїздку за ID
  Future<Trip?> getTripById(String id) async {
    final doc = await tripsCollection.doc(id).get();
    if (!doc.exists) return null;
    return Trip.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Додати пасажира до поїздки
  Future<void> addPassenger(String tripId, String userId) async {
    final tripRef = tripsCollection.doc(tripId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
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
