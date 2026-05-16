import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/trip.dart';
import '../main.dart'; // Щоб взяти ключ MyApp.orsKey
import '../services/trip_service.dart';
import '../services/user_service.dart';
import '../services/review_service.dart';
import '../services/booking_service.dart';
import '../models/booking_request.dart';
import 'departure_search_screen.dart';
import 'arrival_search_screen.dart';
import 'route_selection_screen.dart';
import 'trip_details_screen.dart';
import 'review_screen.dart';
import 'public_profile_screen.dart';

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
  final BookingService _bookingService = BookingService();
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

  String _normalizeCity(String city) {
    return city.split(',').first.trim().toLowerCase();
  }

  int _findCityIndex(List<String> routeCities, String? city) {
    if (city == null || city.trim().isEmpty) return -1;
    final normalized = _normalizeCity(city);
    for (int i = 0; i < routeCities.length; i++) {
      if (_normalizeCity(routeCities[i]) == normalized) {
        return i;
      }
    }
    return -1;
  }

  double _calculateSegmentPrice(Trip trip, {String? fromCity, String? toCity}) {
    final routeCities = <String>[trip.origin.city, ...trip.stops.map((s) => s.city), trip.destination.city];
    if (routeCities.length < 2) return trip.pricePerSeat;

    final fromIdx = _findCityIndex(routeCities, fromCity ?? trip.origin.city);
    final toIdx = _findCityIndex(routeCities, toCity ?? trip.destination.city);
    final totalSegments = routeCities.length - 1;

    if (fromIdx < 0 || toIdx <= fromIdx || totalSegments <= 0) {
      return trip.pricePerSeat;
    }

    final ratio = ((toIdx - fromIdx) / totalSegments).clamp(0.25, 1.0);
    return (trip.pricePerSeat * ratio).roundToDouble();
  }

  ({double price, bool discounted}) _resolveTripCardPrice({
    required Trip trip,
    required String currentUserId,
    required bool isDriver,
    required Map<String, dynamic>? liveData,
  }) {
    if (isDriver) {
      return (price: trip.pricePerSeat, discounted: false);
    }

    final rawSegments = liveData?['passengerSegments'];
    if (rawSegments is Map && rawSegments[currentUserId] is Map) {
      final segment = Map<String, dynamic>.from(rawSegments[currentUserId] as Map);
      final fromCity = segment['fromCity'] as String?;
      final toCity = segment['toCity'] as String?;
      final segmentPrice = (segment['requestedPrice'] as num?)?.toDouble() ??
          _calculateSegmentPrice(trip, fromCity: fromCity, toCity: toCity);
      final discounted = segmentPrice < trip.pricePerSeat;
      return (price: segmentPrice, discounted: discounted);
    }

    return (price: trip.pricePerSeat, discounted: false);
  }

  Future<void> _confirmRequest(BookingRequest request) async {
    final driverData = await _userService.loadUserData(request.driverId);
    final driverName = driverData?['name'] as String? ?? 'Водiй';
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await _bookingService.confirmBookingRequest(requestId: request.id, driverName: driverName);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запит пiдтверджено')),
        );
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _rejectRequest(BookingRequest request) async {
    final driverData = await _userService.loadUserData(request.driverId);
    final driverName = driverData?['name'] as String? ?? 'Водiй';
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await _bookingService.rejectBookingRequest(requestId: request.id, driverName: driverName);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запит вiдхилено')),
        );
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _openDriverRequestsSheet(
    BuildContext context,
    String driverId, {
    String? onlyTripId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.72,
              child: StreamBuilder<List<BookingRequest>>(
                stream: _bookingService.watchDriverPendingRequests(driverId),
                builder: (context, snapshot) {
                  final allRequests = snapshot.data ?? const <BookingRequest>[];
                  final requests = onlyTripId == null
                      ? allRequests
                      : allRequests.where((r) => r.tripId == onlyTripId).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Нові запити',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF7F4),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${requests.length}',
                              style: TextStyle(color: primaryTurquoise, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (requests.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text('Нових запитiв зараз немає'),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: requests.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final request = requests[index];
                              return FutureBuilder<List<dynamic>>(
                                future: Future.wait<dynamic>([
                                  _userService.loadUserData(request.passengerId),
                                  _tripService.getTripById(request.tripId),
                                ]),
                                builder: (context, dataSnapshot) {
                                  final userData = dataSnapshot.data != null
                                      ? (dataSnapshot.data![0] as Map<String, dynamic>? ?? const <String, dynamic>{})
                                      : const <String, dynamic>{};
                                  final tripData = dataSnapshot.data != null
                                      ? dataSnapshot.data![1] as Trip?
                                      : null;
                                  final passengerName = userData['name'] as String? ?? 'Пасажир';
                                  final routeText = (request.fromCity != null && request.toCity != null)
                                      ? '${request.fromCity} -> ${request.toCity}'
                                      : '${tripData?.origin.city ?? 'Маршрут'} -> ${tripData?.destination.city ?? ''}';
                                  final computedPrice = tripData == null
                                      ? null
                                      : _calculateSegmentPrice(
                                          tripData,
                                          fromCity: request.fromCity,
                                          toCity: request.toCity,
                                        );
                                  final requestedPrice = request.requestedPrice ?? computedPrice;

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FCFB),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: primaryTurquoise.withValues(alpha: 0.25)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                         Text(passengerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                         const SizedBox(height: 4),
                                         Text(routeText, style: const TextStyle(color: Colors.black54)),
                                         if (request.pickupAddress != null) ...[
                                           const SizedBox(height: 4),
                                           Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                             decoration: BoxDecoration(
                                               color: primaryTurquoise.withValues(alpha: 0.08),
                                               borderRadius: BorderRadius.circular(6),
                                             ),
                                             child: Row(
                                               children: [
                                                 Icon(Icons.location_on_outlined, size: 14, color: primaryTurquoise),
                                                 const SizedBox(width: 6),
                                                 Expanded(
                                                   child: Text(
                                                     'Посадка: ${request.pickupAddress}',
                                                     maxLines: 1,
                                                     overflow: TextOverflow.ellipsis,
                                                     style: const TextStyle(fontSize: 11, color: Colors.black54),
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ),
                                         ],
                                         if (request.dropoffAddress != null) ...[
                                           const SizedBox(height: 3),
                                           Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                             decoration: BoxDecoration(
                                               color: primaryTurquoise.withValues(alpha: 0.08),
                                               borderRadius: BorderRadius.circular(6),
                                             ),
                                             child: Row(
                                               children: [
                                                 Icon(Icons.flag_outlined, size: 14, color: primaryTurquoise),
                                                 const SizedBox(width: 6),
                                                 Expanded(
                                                   child: Text(
                                                     'Висадка: ${request.dropoffAddress}',
                                                     maxLines: 1,
                                                     overflow: TextOverflow.ellipsis,
                                                     style: const TextStyle(fontSize: 11, color: Colors.black54),
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ),
                                         ],
                                         const SizedBox(height: 6),
                                         OutlinedButton.icon(
                                           onPressed: () {
                                             Navigator.push(
                                               context,
                                               MaterialPageRoute(
                                                 builder: (_) => PublicProfileScreen(
                                                   userId: request.passengerId,
                                                   isMyProfile: false,
                                                 ),
                                               ),
                                             );
                                           },
                                           icon: const Icon(Icons.person_outline_rounded, size: 16),
                                           label: const Text('Профіль пасажира'),
                                           style: OutlinedButton.styleFrom(
                                             foregroundColor: primaryTurquoise,
                                             side: BorderSide(color: primaryTurquoise.withValues(alpha: 0.45)),
                                             minimumSize: const Size.fromHeight(34),
                                           ),
                                         ),
                                        if (requestedPrice != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Цiна для пасажира: ${requestedPrice.toInt()} ₴',
                                            style: TextStyle(color: primaryTurquoise, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () => _confirmRequest(request),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: primaryTurquoise,
                                                  minimumSize: const Size.fromHeight(40),
                                                ),
                                                child: const Text('Пiдтвердити', style: TextStyle(color: Colors.white)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => _rejectRequest(request),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                  side: const BorderSide(color: Colors.red),
                                                  minimumSize: const Size.fromHeight(40),
                                                ),
                                                child: const Text('Вiдхилити'),
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
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
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
        actions: [
          StreamBuilder<List<BookingRequest>>(
            stream: _bookingService.watchDriverPendingRequests(user.uid),
            builder: (context, snapshot) {
              final pendingCount = snapshot.data?.length ?? 0;
              return IconButton(
                tooltip: 'Новi запити',
                onPressed: () => _openDriverRequestsSheet(context, user.uid),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications_active_rounded, color: primaryTurquoise),
                    if (pendingCount > 0)
                      Positioned(
                        right: -4,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            pendingCount > 99 ? '99+' : '$pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
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
              child: StreamBuilder<Map<String, dynamic>?>(
                stream: _tripService.watchTripData(tripObject.id),
                builder: (context, snapshot) {
                  final priceData = _resolveTripCardPrice(
                    trip: tripObject,
                    currentUserId: currentUserId,
                    isDriver: isDriver,
                    liveData: snapshot.data,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${tripObject.departureTime.day}.${tripObject.departureTime.month} | "
                        "${tripObject.departureTime.hour}:${tripObject.departureTime.minute.toString().padLeft(2, '0')} | "
                        "${priceData.price.toInt()} ₴",
                      ),
                      if (priceData.discounted)
                        Text(
                          'Для вас перерахована ціна ділянки',
                          style: TextStyle(color: primaryTurquoise, fontSize: 11.5, fontWeight: FontWeight.w600),
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
                  );
                },
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
          if (isDriver && status == 'active')
            StreamBuilder<List<BookingRequest>>(
              stream: _bookingService.watchTripPendingRequests(tripObject.id),
              builder: (context, snapshot) {
                final pending = snapshot.data ?? const <BookingRequest>[];
                if (pending.isEmpty) {
                  return const SizedBox.shrink();
                }

                return InkWell(
                  onTap: () {
                    _openDriverRequestsSheet(
                      context,
                      currentUserId,
                      onlyTripId: tripObject.id,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7F4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryTurquoise.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active_rounded, color: primaryTurquoise, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Запити на бронювання: ${pending.length}. Натисніть, щоб підтвердити.',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: primaryTurquoise),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}