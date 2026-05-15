import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/trip.dart';
import '../main.dart'; // Щоб взяти ключ MyApp.orsKey
import 'departure_search_screen.dart';
import 'arrival_search_screen.dart';
import 'route_selection_screen.dart';
import 'trip_details_screen.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  final Color primaryTurquoise = const Color(0xFF5DD9C1);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createNewTrip(BuildContext context) async {
    final origin = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DepartureSearchScreen()),
    );
    if (origin == null) return;

    if (!context.mounted) return;
    final destination = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArrivalSearchScreen()),
    );
    if (destination == null) return;

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteSelectionScreen(
          origin: origin,
          destination: destination,
          apiKey: MyApp.orsKey,
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryTurquoise,
          labelColor: primaryTurquoise,
          unselectedLabelColor: Colors.grey,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Активні'),
            Tab(text: 'Завершені'),
            Tab(text: 'Скасовані'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: tripsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Поїздок не знайдено"));
          }

          final now = DateTime.now();
          final tripDocs = snapshot.data!.docs;

          final List<Trip> allTrips = tripDocs
              .map((doc) => Trip.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          // 1. Активні поїздки (статус = 'active' і час ще не прийшов)
          final activeTrips = allTrips
              .where((trip) => trip.status == 'active' && trip.departureTime.isAfter(now))
              .toList()
            ..sort((a, b) => a.departureTime.compareTo(b.departureTime));

          // 2. Завершені поїздки (статус = 'completed' або час вже прийшов і статус != 'cancelled')
          final completedTrips = allTrips
              .where((trip) =>
                  trip.status == 'completed' ||
                  (trip.departureTime.isBefore(now) && trip.status != 'cancelled'))
              .toList()
            ..sort((a, b) => b.departureTime.compareTo(a.departureTime));

          // 3. Скасовані поїздки
          final cancelledTrips = allTrips
              .where((trip) => trip.status == 'cancelled')
              .toList()
            ..sort((a, b) => b.cancelledAt?.compareTo(a.cancelledAt ?? DateTime.now()) ?? -1);

          return TabBarView(
            controller: _tabController,
            children: [
              // Вкладка: Активні
              activeTrips.isEmpty
                  ? const Center(child: Text("Активних поїздок немає"))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: activeTrips.map((trip) => _buildTripItem(context, trip, user.uid, 'active')).toList(),
                    ),

              // Вкладка: Завершені
              completedTrips.isEmpty
                  ? const Center(child: Text("Завершених поїздок немає"))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: completedTrips.map((trip) => _buildTripItem(context, trip, user.uid, 'completed')).toList(),
                    ),

              // Вкладка: Скасовані
              cancelledTrips.isEmpty
                  ? const Center(child: Text("Скасованих поїздок немає"))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: cancelledTrips.map((trip) => _buildTripItem(context, trip, user.uid, 'cancelled')).toList(),
                    ),
            ],
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

  Widget _buildTripItem(BuildContext context, Trip tripObject, String currentUserId, String status) {
    final bool isDriver = tripObject.driverId == currentUserId;
    Color statusColor = primaryTurquoise;
    String statusLabel = 'Активна';

    if (status == 'completed') {
      statusColor = Colors.green;
      statusLabel = 'Завершена';
    } else if (status == 'cancelled') {
      statusColor = Colors.red;
      statusLabel = 'Скасована';
    }

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
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            isDriver ? Icons.drive_eta_rounded : Icons.person_pin_circle_rounded,
            color: statusColor,
          ),
        ),
        title: Text(
          "${tripObject.origin.city} → ${tripObject.destination.city}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${tripObject.departureTime.day}.${tripObject.departureTime.month} | "
                "${tripObject.departureTime.hour}:${tripObject.departureTime.minute.toString().padLeft(2, '0')} | "
                "${tripObject.pricePerSeat.toInt()} ₴",
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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
  }
}