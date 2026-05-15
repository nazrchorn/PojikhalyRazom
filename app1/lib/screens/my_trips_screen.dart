import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/trip.dart';
import '../main.dart'; // Щоб взяти ключ MyApp.orsKey
import 'departure_search_screen.dart';
import 'arrival_search_screen.dart';
import 'route_selection_screen.dart';
import 'trip_details_screen.dart';

class MyTripsScreen extends StatelessWidget {
  const MyTripsScreen({super.key});

  final Color primaryTurquoise = const Color(0xFF5DD9C1);

  // Функція для послідовного створення поїздки
  Future<void> _createNewTrip(BuildContext context) async {
    // Крок 1: Вибір точки відправлення
    final origin = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DepartureSearchScreen()),
    );
    if (origin == null) return;

    // Крок 2: Вибір точки прибуття
    if (!context.mounted) return;
    final destination = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArrivalSearchScreen()),
    );
    if (destination == null) return;

    // Крок 3: Вибір маршруту на карті
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteSelectionScreen(
          origin: origin,
          destination: destination,
          apiKey: MyApp.orsKey, // Використовуємо ключ для побудови доріг
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Спочатку увійдіть у систему")),
      );
    }

    final tripsQuery = FirebaseFirestore.instance
        .collection('trips')
        .where(Filter.or(
      Filter('driverId', isEqualTo: user.uid),
      Filter('passengers', arrayContains: user.uid),
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text("Мої поїздки", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: tripsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Поки що немає запланованих поїздок"));
          }

          final tripDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tripDocs.length,
            itemBuilder: (context, index) {
              final doc = tripDocs[index];

              final Trip tripObject = Trip.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id
              );

              final bool isDriver = tripObject.driverId == user.uid;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isDriver ? primaryTurquoise.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    child: Icon(
                      isDriver ? Icons.drive_eta_rounded : Icons.person_pin_circle_rounded,
                      color: isDriver ? primaryTurquoise : Colors.blue,
                    ),
                  ),
                  title: Text(
                    "${tripObject.origin.city} → ${tripObject.destination.city}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "${tripObject.departureTime.day}.${tripObject.departureTime.month} | "
                          "${tripObject.departureTime.hour}:${tripObject.departureTime.minute.toString().padLeft(2, '0')} | "
                          "${tripObject.pricePerSeat.toInt()} ₴",
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripDetailScreen(trip: tripObject),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryTurquoise,
        onPressed: () => _createNewTrip(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}