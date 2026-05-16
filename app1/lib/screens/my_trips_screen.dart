import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/trip.dart';
import '../main.dart'; // Щоб взяти ключ MyApp.orsKey
import '../services/trip_service.dart';
import '../services/user_service.dart';
import '../services/review_service.dart';
import 'departure_search_screen.dart';
import 'arrival_search_screen.dart';
import 'route_selection_screen.dart';
import 'trip_details_screen.dart';
import 'review_screen.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TripService _tripService = TripService();
  final UserService _userService = UserService();
  final ReviewService _reviewService = ReviewService();
  final Set<String> _promptedReviewTrips = <String>{};
  bool _reviewFlowActive = false;

  final Color primaryTurquoise = const Color(0xFF2F8F7F);

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

  Future<void> _maybePromptForReviews(List<Trip> trips, String currentUserId) async {
    if (_reviewFlowActive || currentUserId.isEmpty) {
      return;
    }

    final now = DateTime.now();
    Trip? completedCandidate;
    List<Map<String, dynamic>> pendingTargets = <Map<String, dynamic>>[];

    for (final trip in trips) {
      final bool isCompleted =
          trip.status != 'cancelled' &&
          (trip.status == 'completed' || trip.isCompletedByTime(now)) &&
          (trip.driverId == currentUserId || trip.passengers.contains(currentUserId)) &&
          !_promptedReviewTrips.contains(trip.id);
      if (!isCompleted) {
        continue;
      }

      final targets = await _loadPendingReviewTargets(trip, currentUserId);
      if (targets.isEmpty) {
        continue;
      }

      completedCandidate = trip;
      pendingTargets = targets;
      break;
    }

    if (completedCandidate == null) {
      return;
    }

    final Trip candidate = completedCandidate;
    if (!mounted) return;

    _promptedReviewTrips.add(candidate.id);
    final bool? startReviews = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Поїздка завершена'),
        content: Text(
          candidate.driverId == currentUserId
              ? 'Можна послідовно залишити відгуки для ${pendingTargets.length} пасажирів.'
              : 'Можна залишити відгук про водія після завершення поїздки.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Пізніше'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryTurquoise),
            child: const Text('Написати відгук', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (startReviews != true) {
      return;
    }

    _reviewFlowActive = true;
    try {
      await _runSequentialReviewFlow(candidate, currentUserId, pendingTargets: pendingTargets);
    } finally {
      _reviewFlowActive = false;
    }
  }

  Future<List<Map<String, dynamic>>> _loadPendingReviewTargets(Trip trip, String currentUserId) async {
    final bool isDriver = trip.driverId == currentUserId;
    final List<String> targetIds = isDriver ? List<String>.from(trip.passengers) : <String>[trip.driverId];
    final List<Map<String, dynamic>> targets = <Map<String, dynamic>>[];

    for (final targetId in targetIds) {
      final targetData = await _userService.loadUserData(targetId);
      if (targetData == null) {
        continue;
      }

      final bool reviewed = await _reviewService.hasUserReviewedTripForTarget(
        fromUserId: currentUserId,
        toUserId: targetId,
        tripId: trip.id,
      );
      if (reviewed) {
        continue;
      }

      targets.add(<String, dynamic>{
        'id': targetId,
        'name': targetData['name'] as String? ?? 'Користувач',
        'photoUrl': targetData['photoUrl'],
      });
    }

    return targets;
  }

  Future<void> _runSequentialReviewFlow(
    Trip trip,
    String currentUserId, {
    required List<Map<String, dynamic>> pendingTargets,
  }) async {
    final bool isDriver = trip.driverId == currentUserId;

    for (final target in pendingTargets) {
      if (!mounted) return;

      final String targetId = target['id'] as String;
      final targetData = await _userService.loadUserData(targetId);
      if (!mounted) return;
      if (targetData == null) {
        continue;
      }

      final shouldOpenReview = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewScreen(
            tripId: trip.id,
            fromUserId: currentUserId,
            toUserId: targetId,
            toUserName: target['name'] as String? ?? 'Користувач',
            toUserPhotoUrl: target['photoUrl'] as String?,
            role: isDriver ? 'driver' : 'passenger',
          ),
        ),
      );

      if (shouldOpenReview != true && !mounted) {
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дякуємо, відгуки збережено')),
      );
    }
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

    return Scaffold(
      backgroundColor: const Color(0xFFF6FCFA),
      appBar: AppBar(
        title: const Text("Мої поїздки", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFF4FBF9),
        surfaceTintColor: const Color(0xFFF4FBF9),
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
      body: StreamBuilder<List<Trip>>(
        stream: _tripService.getUserTrips(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Поїздок не знайдено"));
          }

          final now = DateTime.now();
          final List<Trip> allTrips = snapshot.data!;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _maybePromptForReviews(allTrips, user.uid);
            }
          });

          // 1. Активні поїздки (ще не завершені та не скасовані)
          final activeTrips = allTrips
              .where((trip) => trip.status != 'completed' && trip.status != 'cancelled' && !trip.isCompletedByTime(now))
              .toList()
            ..sort((a, b) => a.departureTime.compareTo(b.departureTime));

          // 2. Завершені поїздки (статус = 'completed' або минув плановий час прибуття)
          final completedTrips = allTrips
              .where((trip) =>
                  trip.status == 'completed' ||
                  (trip.isCompletedByTime(now) && trip.status != 'cancelled'))
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
    final now = DateTime.now();
    final bool isInProgress = tripObject.status == 'in_progress' || tripObject.isInProgressByTime(now);
    Color statusColor = primaryTurquoise;
    String statusLabel = isInProgress ? 'В процесі' : 'Активна';

    if (status == 'completed') {
      statusColor = Colors.green;
      statusLabel = 'Завершена';
    } else if (status == 'cancelled') {
      statusColor = Colors.red;
      statusLabel = 'Скасована';
    } else if (isInProgress) {
      statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
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
                  color: statusColor.withValues(alpha: 0.1),
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