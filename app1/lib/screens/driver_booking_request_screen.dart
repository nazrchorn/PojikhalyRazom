import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/booking_request.dart';
import '../models/trip.dart';
import '../services/booking_service.dart';
import '../services/trip_service.dart';
import '../services/user_service.dart';

class DriverBookingRequestScreen extends StatefulWidget {
  final String requestId;

  const DriverBookingRequestScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<DriverBookingRequestScreen> createState() => _DriverBookingRequestScreenState();
}

class _DriverBookingRequestScreenState extends State<DriverBookingRequestScreen> {
  final BookingService _bookingService = BookingService();
  final TripService _tripService = TripService();
  final UserService _userService = UserService();

  final Color primaryTurquoise = const Color(0xFF1F6F66);
  bool _actionInProgress = false;

  Future<void> _confirmRequest(BookingRequest request) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid != request.driverId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Підтверджувати може тільки водій цієї поїздки')),
      );
      return;
    }

    setState(() => _actionInProgress = true);
    try {
      final driverData = await _userService.loadUserData(request.driverId);
      final driverName = driverData?['name'] as String? ?? 'Водій';
      await _bookingService.confirmBookingRequest(requestId: request.id, driverName: driverName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запит підтверджено')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося підтвердити: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      }
    }
  }

  Future<void> _rejectRequest(BookingRequest request) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid != request.driverId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Відхиляти може тільки водій цієї поїздки')),
      );
      return;
    }

    setState(() => _actionInProgress = true);
    try {
      final driverData = await _userService.loadUserData(request.driverId);
      final driverName = driverData?['name'] as String? ?? 'Водій';
      await _bookingService.rejectBookingRequest(requestId: request.id, driverName: driverName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запит відхилено')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося відхилити: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      }
    }
  }

  Widget _buildRequestMap(Trip trip, BookingRequest request) {
    final List<Marker> markers = <Marker>[
      Marker(
        point: LatLng(trip.origin.lat, trip.origin.lng),
        width: 40,
        height: 40,
        child: const Icon(Icons.play_circle_fill, color: Colors.green, size: 34),
      ),
      Marker(
        point: LatLng(trip.destination.lat, trip.destination.lng),
        width: 40,
        height: 40,
        child: const Icon(Icons.stop_circle, color: Colors.red, size: 34),
      ),
      ...trip.stops.map(
        (stop) => Marker(
          point: LatLng(stop.lat, stop.lng),
          width: 30,
          height: 30,
          child: const Icon(Icons.trip_origin, color: Color(0xFF26A69A), size: 18),
        ),
      ),
    ];

    if (request.pickupLat != null && request.pickupLng != null) {
      markers.add(
        Marker(
          point: LatLng(request.pickupLat!, request.pickupLng!),
          width: 46,
          height: 46,
          child: const Icon(Icons.location_on, color: Colors.blue, size: 38),
        ),
      );
    }

    if (request.dropoffLat != null && request.dropoffLng != null) {
      markers.add(
        Marker(
          point: LatLng(request.dropoffLat!, request.dropoffLng!),
          width: 46,
          height: 46,
          child: const Icon(Icons.flag_circle, color: Color(0xFF1F6F66), size: 34),
        ),
      );
    }

    final LatLng initialCenter = (request.pickupLat != null && request.pickupLng != null)
        ? LatLng(request.pickupLat!, request.pickupLng!)
        : LatLng(trip.origin.lat, trip.origin.lng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 260,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 9,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.pojikhaly_razom',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Прийняття пасажира'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Theme.of(context).appBarTheme.surfaceTintColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: StreamBuilder<BookingRequest?>(
        stream: _bookingService.watchRequestById(widget.requestId),
        builder: (context, requestSnapshot) {
          if (requestSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final request = requestSnapshot.data;
          if (request == null) {
            return const Center(child: Text('Запит не знайдено або вже видалено'));
          }

          return FutureBuilder<List<dynamic>>(
            future: Future.wait<dynamic>([
              _tripService.getTripById(request.tripId),
              _userService.loadUserData(request.passengerId),
            ]),
            builder: (context, dataSnapshot) {
              if (dataSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final trip = dataSnapshot.data != null ? dataSnapshot.data![0] as Trip? : null;
              final passenger = dataSnapshot.data != null
                  ? dataSnapshot.data![1] as Map<String, dynamic>?
                  : null;

              if (trip == null) {
                return const Center(child: Text('Поїздку для цього запиту не знайдено'));
              }

              final passengerName = passenger?['name'] as String? ?? 'Пасажир';
              final routeText = (request.fromCity != null && request.toCity != null)
                  ? '${request.fromCity} -> ${request.toCity}'
                  : '${trip.origin.city} -> ${trip.destination.city}';

              final canAct = request.status == 'pending' &&
                  FirebaseAuth.instance.currentUser?.uid == request.driverId;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: primaryTurquoise.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(passengerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(routeText, style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 6),
                          Text(
                            request.requestedPrice != null
                                ? 'Ціна для пасажира: ${request.requestedPrice!.toInt()} ₴'
                                : 'Ціна: буде розрахована по сегменту',
                            style: TextStyle(color: primaryTurquoise, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StatusChip(label: 'Статус: ${request.status}', color: primaryTurquoise),
                              if (request.pickupAddress != null)
                                _StatusChip(label: 'Посадка: задана', color: Colors.blue),
                              if (request.dropoffAddress != null)
                                _StatusChip(label: 'Висадка: задана', color: const Color(0xFF1F6F66)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRequestMap(trip, request),
                    const SizedBox(height: 10),
                    if (request.pickupAddress != null)
                      Text('Посадка: ${request.pickupAddress}', style: const TextStyle(fontSize: 13)),
                    if (request.dropoffAddress != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Висадка: ${request.dropoffAddress}', style: const TextStyle(fontSize: 13)),
                      ),
                    const SizedBox(height: 16),
                    if (!canAct)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          request.status == 'pending'
                              ? 'Цей запит може підтверджувати тільки водій поїздки.'
                              : 'Запит вже оброблено: ${request.status}.',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _actionInProgress ? null : () => _confirmRequest(request),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryTurquoise,
                                minimumSize: const Size.fromHeight(46),
                              ),
                              child: const Text('Підтвердити', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _actionInProgress ? null : () => _rejectRequest(request),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                minimumSize: const Size.fromHeight(46),
                              ),
                              child: const Text('Відхилити'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

