import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math' show cos, sqrt, asin;
import '../models/trip.dart';
import '../models/user.dart' as app_user;
import 'public_profile_screen.dart';
import 'trip_details_map_screen.dart';

class TripDetailScreen extends StatelessWidget {
  final Trip trip;
  final bool showBookingButton;

  const TripDetailScreen({
    super.key,
    required this.trip,
    this.showBookingButton = false,
  });

  // Палітра кольорів
  final Color primaryTurquoise = const Color(0xFF5DD9C1);
  final Color mapIconColor = const Color(0xFF4DB6AC);
  final Color priceTextColor = const Color(0xFF26A69A);
  final Color backgroundDeep = const Color(0xFFF2F5F8);
  final Color bgTurquoiseLight = const Color(0xFFE0F2F1);
  final Color inactiveGrey = const Color(0xFFB0BEC5); // Сірий для заборон

  // Розрахунок часу прибуття по координатах (виправлено назви полів на lat/lng)
  String _estimateArrivalTime(Trip trip) {
    double lat1 = trip.origin.lat;
    double lon1 = trip.origin.lng;
    double lat2 = trip.destination.lat;
    double lon2 = trip.destination.lng;

    const r = 6371;
    double p = 0.017453292519943295;
    double a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

    double distance = 2 * r * asin(sqrt(a));
    double hours = distance / 75;
    DateTime arrival = trip.departureTime.add(Duration(minutes: (hours * 60).toInt() + 15));

    return "${arrival.hour}:${arrival.minute.toString().padLeft(2, '0')}";
  }

  String _getFormattedDate(DateTime date) {
    final List<String> weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Нд"];
    final List<String> months = ["січня", "лютого", "березня", "квітня", "травня", "червня", "липня", "серпня", "вересня", "жовтня", "листопада", "грудня"];
    return "${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}";
  }

  // ОНОВЛЕНИЙ ФІЛЬТР: Якщо isDisabled = true, то колір сірий
  Widget _buildModernFilter(String text, IconData icon, {bool isAccent = false, bool isDisabled = false}) {
    Color contentColor = isDisabled ? inactiveGrey : (isAccent ? Colors.white : mapIconColor);
    Color bgColor = isAccent ? primaryTurquoise : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDisabled ? 0.02 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)
          )
        ],
        border: isDisabled ? Border.all(color: inactiveGrey.withOpacity(0.2)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 14, color: contentColor),
          const SizedBox(width: 8),
          Text(
              text,
              style: TextStyle(
                  color: isDisabled ? inactiveGrey : Colors.blueGrey.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 12
              )
          ),
        ],
      ),
    );
  }

  Widget _cardWrapper({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _buildTimelinePoint({required String time, required String city, required bool isLast, required VoidCallback onTap, bool isFirst = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            SizedBox(width: 50, child: Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey))),
            const SizedBox(width: 8),
            Column(
              children: [
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(color: isFirst || isLast ? primaryTurquoise : Colors.white, border: Border.all(color: primaryTurquoise, width: 3), shape: BoxShape.circle),
                ),
                if (!isLast) Container(width: 2, height: 40, color: primaryTurquoise.withOpacity(0.2)),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(child: Text(city, style: TextStyle(fontSize: 17, fontWeight: isFirst || isLast ? FontWeight.bold : FontWeight.w500))),
            Icon(Icons.map_outlined, color: mapIconColor.withOpacity(0.8), size: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('trips').doc(trip.id).snapshots(),
      builder: (context, snapshot) {
        int liveSeats = trip.availableSeats;
        List<dynamic> passengerIds = [];
        if (snapshot.hasData && snapshot.data!.exists) {
          liveSeats = snapshot.data!['availableSeats'] ?? trip.availableSeats;
          passengerIds = snapshot.data!['passengers'] ?? [];
        }

        return Scaffold(
          backgroundColor: backgroundDeep,
          appBar: AppBar(
            title: const Text("Деталі поїздки"),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
            foregroundColor: Colors.black87,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardWrapper(
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, color: primaryTurquoise),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_getFormattedDate(trip.departureTime), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text("Відправлення о ${trip.departureTime.hour}:${trip.departureTime.minute.toString().padLeft(2, '0')}", style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      const Text("Маршрут", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _cardWrapper(
                        child: Column(
                          children: [
                            _buildTimelinePoint(
                              time: "${trip.departureTime.hour}:${trip.departureTime.minute.toString().padLeft(2,'0')}",
                              city: trip.origin.city, isFirst: true, isLast: false, onTap: () => _openMap(context),
                            ),
                            _buildTimelinePoint(
                              time: _estimateArrivalTime(trip),
                              city: trip.destination.city, isFirst: false, isLast: true, onTap: () => _openMap(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: _cardWrapper(
                              child: Column(
                                children: [
                                  Text("${trip.pricePerSeat.toInt()} ₴", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: priceTextColor)),
                                  const Text("ціна за місце", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _cardWrapper(
                              child: Column(
                                children: [
                                  Text("$liveSeats", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                  const Text("вільних місць", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      const Text("Особливості", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10, runSpacing: 10,
                        children: [
                          if (trip.womenOnly) _buildModernFilter("Тільки жінки", FontAwesomeIcons.personDress, isAccent: true),
                          // Тварини: якщо не можна, то сірий колір
                          _buildModernFilter(
                              trip.allowPets ? "З тваринами" : "Без тварин",
                              FontAwesomeIcons.paw,
                              isDisabled: !trip.allowPets
                          ),
                          // Діти: якщо не можна, то сірий колір
                          _buildModernFilter(
                              trip.allowChildren ? "Можна з дітьми" : "Без дітей",
                              FontAwesomeIcons.child,
                              isDisabled: !trip.allowChildren
                          ),
                          _buildModernFilter("Не палити", FontAwesomeIcons.smokingBan),
                        ],
                      ),
                      if (passengerIds.isNotEmpty) ...[
                        const SizedBox(height: 25),
                        const Text("Пасажири", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: passengerIds.length,
                            itemBuilder: (context, index) => _buildPassengerAvatar(context, passengerIds[index]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _buildBottomPanel(context, liveSeats),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel(BuildContext context, int liveSeats) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(trip.driverId).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final user = app_user.User.fromMap(snapshot.data!.id, snapshot.data!.data() as Map<String, dynamic>);
              return InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: user.id))),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: bgTurquoiseLight,
                      backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty) ? NetworkImage(user.photoUrl!) : null,
                      child: (user.photoUrl == null || user.photoUrl!.isEmpty) ? Icon(Icons.person, color: primaryTurquoise) : null,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text("${user.rating.toStringAsFixed(1)} ★ • ${user.tripsCompleted} поїздок", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              );
            },
          ),
          if (showBookingButton && liveSeats > 0) ...[
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () => _handleBooking(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTurquoise,
                minimumSize: const Size.fromHeight(55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text("Забронювати", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPassengerAvatar(BuildContext context, String passengerId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(passengerId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(width: 60);
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String? photo = data['photoUrl'];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: passengerId))),
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: bgTurquoiseLight,
              backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
              child: (photo == null || photo.isEmpty) ? Icon(Icons.person, color: primaryTurquoise) : null,
            ),
          ),
        );
      },
    );
  }

  void _openMap(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsMapScreen(trip: trip, apiKey: "YOUR_KEY")));
  }

  Future<void> _handleBooking(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      final tripRef = FirebaseFirestore.instance.collection('trips').doc(trip.id);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(tripRef);
        final int seats = snap.data()?['availableSeats'] ?? 0;
        final List pass = snap.data()?['passengers'] ?? [];
        if (pass.contains(user.uid) || seats <= 0) throw "Error";
        tx.update(tripRef, {'availableSeats': seats - 1, 'passengers': FieldValue.arrayUnion([user.uid])});
      });
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }
}