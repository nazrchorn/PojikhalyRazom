import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math' show cos, sqrt, asin;
import '../models/trip.dart';
import '../models/booking_request.dart';
import '../models/user.dart' as app_user;
import '../main.dart';
import '../services/trip_service.dart';
import '../services/user_service.dart';
import '../services/review_service.dart';
import '../services/booking_service.dart';
import '../services/chat_service.dart';
import 'public_profile_screen.dart';
import 'trip_details_map_screen.dart';
import 'messanger_screen.dart';
import 'review_screen.dart';

class TripDetailScreen extends StatelessWidget {
  final Trip trip;
  final bool showBookingButton;
  final String? bookingFromCity;
  final String? bookingToCity;

  TripDetailScreen({
    super.key,
    required this.trip,
    this.showBookingButton = false,
    this.bookingFromCity,
    this.bookingToCity,
  });

  // Палітра кольорів
  final Color primaryTurquoise = const Color(0xFF2F8F7F);
  final Color mapIconColor = const Color(0xFF4DB6AC);
  final Color priceTextColor = const Color(0xFF26A69A);
  final Color backgroundDeep = const Color(0xFFF2F5F8);
  final Color bgTurquoiseLight = const Color(0xFFE0F2F1);
  final Color inactiveGrey = const Color(0xFFB0BEC5); // Сірий для заборон
  final TripService _tripService = TripService();
  final UserService _userService = UserService();
  final ReviewService _reviewService = ReviewService();
  final BookingService _bookingService = BookingService();
  final ChatService _chatService = ChatService();

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

  String _normalizeCity(String city) {
    return city.split(',').first.trim().toLowerCase();
  }

  DateTime _getPlannedArrival(Trip sourceTrip) {
    final byModel = sourceTrip.getPlannedArrivalTime();
    if (byModel.isAfter(sourceTrip.departureTime)) {
      return byModel;
    }
    final String hhmm = _estimateArrivalTime(sourceTrip);
    final parts = hhmm.split(':');
    final int h = int.tryParse(parts.first) ?? sourceTrip.departureTime.hour;
    final int m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? sourceTrip.departureTime.minute;
    return DateTime(
      sourceTrip.departureTime.year,
      sourceTrip.departureTime.month,
      sourceTrip.departureTime.day,
      h,
      m,
    );
  }

  List<String> _buildRouteCities(Trip sourceTrip) {
    return <String>[
      sourceTrip.origin.city,
      ...sourceTrip.stops.map((s) => s.city),
      sourceTrip.destination.city,
    ];
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
              color: Colors.black.withValues(alpha: isDisabled ? 0.02 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)
          )
        ],
        border: isDisabled ? Border.all(color: inactiveGrey.withValues(alpha: 0.2)) : null,
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _buildTimelinePoint({
    required String time,
    required String city,
    required bool isLast,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isHighlighted = false,
  }) {
    final Color markerColor = isHighlighted ? Colors.orange : primaryTurquoise;
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
                  decoration: BoxDecoration(
                    color: isFirst || isLast || isHighlighted ? markerColor : Colors.white,
                    border: Border.all(color: markerColor, width: 3),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast) Container(width: 2, height: 40, color: markerColor.withValues(alpha: 0.2)),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                city,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: isFirst || isLast || isHighlighted ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.map_outlined, color: mapIconColor.withValues(alpha: 0.8), size: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _tripService.watchTripData(trip.id),
      builder: (context, snapshot) {
        int liveSeats = trip.availableSeats;
        List<dynamic> passengerIds = [];
        final liveData = snapshot.data;
        final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
        String? currentSegmentFrom = bookingFromCity;
        String? currentSegmentTo = bookingToCity;
        if (snapshot.hasData && liveData != null) {
          liveSeats = liveData['availableSeats'] ?? trip.availableSeats;
          passengerIds = List<dynamic>.from(liveData['passengers'] ?? []);
          final segmentsRaw = liveData['passengerSegments'];
          if (segmentsRaw is Map && currentUserId.isNotEmpty && segmentsRaw[currentUserId] is Map) {
            final segment = Map<String, dynamic>.from(segmentsRaw[currentUserId] as Map);
            currentSegmentFrom = segment['fromCity'] as String? ?? currentSegmentFrom;
            currentSegmentTo = segment['toCity'] as String? ?? currentSegmentTo;
          }
        }

        final routeCities = _buildRouteCities(trip);
        final DateTime arrivalTime = _getPlannedArrival(trip);
        final int totalMinutes = arrivalTime.difference(trip.departureTime).inMinutes;

        return Scaffold(
          backgroundColor: backgroundDeep,
          appBar: AppBar(
            title: const Text("Деталі поїздки"),
            centerTitle: true,
            backgroundColor: const Color(0xFFF4FBF9),
            surfaceTintColor: const Color(0xFFF4FBF9),
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
                          children: List.generate(routeCities.length, (index) {
                            final int minutesFromStart = routeCities.length <= 1
                                ? 0
                                : ((totalMinutes * index) / (routeCities.length - 1)).round();
                            final DateTime pointTime = trip.departureTime.add(Duration(minutes: minutesFromStart));
                            final String pointTimeText =
                                '${pointTime.hour}:${pointTime.minute.toString().padLeft(2, '0')}';
                            final String cityName = routeCities[index];
                            final bool highlighted =
                                _normalizeCity(cityName) == _normalizeCity(currentSegmentFrom ?? '') ||
                                _normalizeCity(cityName) == _normalizeCity(currentSegmentTo ?? '');

                            return _buildTimelinePoint(
                              time: pointTimeText,
                              city: cityName,
                              isFirst: index == 0,
                              isLast: index == routeCities.length - 1,
                              isHighlighted: highlighted,
                              onTap: () => _openMap(context, currentSegmentFrom, currentSegmentTo),
                            );
                          }),
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
                          _buildModernFilter("Не палити", FontAwesomeIcons.banSmoking),
                        ],
                      ),
                      if (passengerIds.isNotEmpty) ...[
                        const SizedBox(height: 25),
                        const Text("Пасажири", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 92,
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
              _buildBottomPanel(
                context,
                liveSeats,
                passengerIds.map((e) => e.toString()).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel(BuildContext context, int liveSeats, List<String> livePassengerIds) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isDriver = trip.driverId == currentUserId;
    final bool isPassenger = livePassengerIds.contains(currentUserId);
    final DateTime now = DateTime.now();
    final bool isTripCompleted = trip.status == 'completed' || trip.isCompletedByTime(now);
    final bool isTripInProgress = trip.status == 'in_progress' || trip.isInProgressByTime(now);
    final bool canModifyTrip = trip.status == 'active' && !trip.hasStartedByTime(now);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 15)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<app_user.User?>(
            future: _userService.loadUser(trip.driverId),
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user == null) return const SizedBox();
              final bool canMessageDriver =
                  currentUserId.isNotEmpty && currentUserId != user.id;

              return Column(
                children: [
                  InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: user.id, isMyProfile: false,))),
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
                  ),
                  if (canMessageDriver) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              currentUserId: currentUserId,
                              partnerId: user.id,
                              partnerName: user.name,
                              partnerPhotoUrl: user.photoUrl,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Написати водiю'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: primaryTurquoise,
                        side: BorderSide(color: primaryTurquoise.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          if (isTripInProgress) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                'Поїздка вже в процесі',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],

          if (isDriver && !isTripCompleted && canModifyTrip) ...[
            const SizedBox(height: 12),
            _buildDriverRequestsPanel(context),
          ],

          if (!isDriver && showBookingButton && !isTripCompleted && canModifyTrip) ...[
            const SizedBox(height: 12),
            StreamBuilder<BookingRequest?>(
              stream: _bookingService.watchPassengerLatestRequest(trip.id, currentUserId),
              builder: (context, snapshot) {
                final request = snapshot.data;
                final bool hasPending = request?.status == 'pending';
                final bool hasConfirmed = isPassenger || request?.status == 'confirmed';

                if (hasPending) {
                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: const Text(
                          'Запит на бронювання надiслано. Очiкуйте пiдтвердження водiя.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => _cancelBooking(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Скасувати запит', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  );
                }

                if (hasConfirmed) {
                  return OutlinedButton(
                    onPressed: () => _cancelBooking(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Скасувати бронювання', style: TextStyle(fontWeight: FontWeight.bold)),
                  );
                }

                if (liveSeats <= 0) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Немає вiльних мiсць для запиту',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return ElevatedButton(
                  onPressed: () => _sendBookingRequest(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTurquoise,
                    minimumSize: const Size.fromHeight(55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Надiслати запит на бронювання',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                );
              },
            ),
          ],

          // Кнопка скасування для водія
          if (isDriver && !isTripCompleted && canModifyTrip) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _cancelTrip(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Скасувати поїздку', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
          // Кнопка відгуку
          if (isTripCompleted && (isDriver || isPassenger) && currentUserId.isNotEmpty) ...[
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadReviewTargets(currentUserId),
              builder: (context, snapshot) {
                final targets = snapshot.data ?? const <Map<String, dynamic>>[];
                if (targets.isEmpty) {
                  return const SizedBox.shrink();
                }
                final bool allReviewed = targets.every((t) => t['reviewed'] == true);
                if (allReviewed) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text(
                      '✓ Ви вже залишили відгук',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ElevatedButton(
                  onPressed: () => _openReviewTargetPicker(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Залишити відгук', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPassengerAvatar(BuildContext context, String passengerId) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return FutureBuilder<Map<String, dynamic>?>(
      future: _userService.loadUserData(passengerId),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox(width: 60);
        final String userName = (data['name'] as String?)?.trim().isNotEmpty == true
            ? (data['name'] as String)
            : 'Користувач';
        final String? photo = data['photoUrl'];
        final bool canMessage = currentUserId.isNotEmpty && currentUserId != passengerId;

        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            width: 68,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: passengerId, isMyProfile: false,))),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: bgTurquoiseLight,
                    backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
                    child: (photo == null || photo.isEmpty) ? Icon(Icons.person, color: primaryTurquoise) : null,
                  ),
                ),
                const SizedBox(height: 6),
                if (canMessage)
                  SizedBox(
                    height: 26,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              currentUserId: currentUserId,
                              partnerId: passengerId,
                              partnerName: userName,
                              partnerPhotoUrl: photo,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 12),
                      label: const Text('Чат', style: TextStyle(fontSize: 10)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        foregroundColor: primaryTurquoise,
                        side: BorderSide(color: primaryTurquoise.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 26),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openMap(BuildContext context, String? highlightedFromCity, String? highlightedToCity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripDetailsMapScreen(
          trip: trip,
          apiKey: MyApp.orsKey,
          highlightedFromCity: highlightedFromCity,
          highlightedToCity: highlightedToCity,
        ),
      ),
    );
  }

  Widget _buildDriverRequestsPanel(BuildContext context) {
    return StreamBuilder<List<BookingRequest>>(
      stream: _bookingService.watchTripPendingRequests(trip.id),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <BookingRequest>[];
        if (requests.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Запити на бронювання',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...requests.map((request) {
                return FutureBuilder<Map<String, dynamic>?>(
                  future: _userService.loadUserData(request.passengerId),
                  builder: (context, userSnap) {
                    final userData = userSnap.data ?? const <String, dynamic>{};
                    final passengerName = userData['name'] as String? ?? 'Пасажир';
                    final routeText = (request.fromCity != null && request.toCity != null)
                        ? '${request.fromCity} -> ${request.toCity}'
                        : 'Маршрут поїздки';

                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(passengerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(routeText, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _confirmRequest(context, request),
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
                                  onPressed: () => _rejectRequest(context, request),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(40),
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
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
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendBookingRequest(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final passengerData = await _userService.loadUserData(user.uid);
    final passengerName = passengerData?['name'] as String? ?? 'Пасажир';
    if (!context.mounted) return;

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      await _bookingService.createBookingRequest(
        tripId: trip.id,
        driverId: trip.driverId,
        passengerId: user.uid,
        passengerName: passengerName,
        fromCity: bookingFromCity,
        toCity: bookingToCity,
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запит на бронювання надiслано водiю')),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _confirmRequest(BuildContext context, BookingRequest request) async {
    final driverData = await _userService.loadUserData(request.driverId);
    final driverName = driverData?['name'] as String? ?? 'Водiй';
    if (!context.mounted) return;

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      await _bookingService.confirmBookingRequest(requestId: request.id, driverName: driverName);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запит пiдтверджено')),
        );
      }
    } catch (_) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _rejectRequest(BuildContext context, BookingRequest request) async {
    final driverData = await _userService.loadUserData(request.driverId);
    final driverName = driverData?['name'] as String? ?? 'Водiй';
    if (!context.mounted) return;

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      await _bookingService.rejectBookingRequest(requestId: request.id, driverName: driverName);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запит вiдхилено')),
        );
      }
    } catch (_) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _cancelBooking(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Скасувати бронювання?'),
        content: const Text('Ви впевнені, що хочете скасувати своє місце в цій поїздці?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ні'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Так', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      await _bookingService.cancelLatestByPassenger(tripId: trip.id, passengerId: user.uid);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Бронювання скасовано')),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _cancelTrip(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Скасувати поїздку?'),
        content: const Text('Це сповістить усіх пасажирів про скасування.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ні'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Так', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      await _tripService.cancelTrip(
        tripId: trip.id,
        cancelledBy: FirebaseAuth.instance.currentUser?.uid ?? '',
      );
      final driverData = await _userService.loadUserData(trip.driverId);
      final driverName = driverData?['name'] as String? ?? 'Водiй';
      for (final passengerId in trip.passengers) {
        await _chatService.sendSystemMessage(
          receiverId: passengerId,
          tripId: trip.id,
          type: 'trip_cancelled',
          text: '$driverName скасував поїздку. Ви можете знайти iнший варiант у пошуку.',
        );
      }
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Поїздку скасовано')),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<List<Map<String, dynamic>>> _loadReviewTargets(String currentUserId) async {
    if (currentUserId.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final List<String> targetIds = currentUserId == trip.driverId
        ? List<String>.from(trip.passengers)
        : <String>[trip.driverId];

    final List<Map<String, dynamic>> targets = <Map<String, dynamic>>[];
    for (final targetId in targetIds) {
      final userData = await _userService.loadUserData(targetId);
      if (userData == null) {
        continue;
      }
      final reviewed = await _reviewService.hasUserReviewedTripForTarget(
        fromUserId: currentUserId,
        toUserId: targetId,
        tripId: trip.id,
      );

      targets.add(<String, dynamic>{
        'id': targetId,
        'name': userData['name'] ?? 'Користувач',
        'photoUrl': userData['photoUrl'],
        'reviewed': reviewed,
      });
    }

    return targets;
  }

  Future<void> _openReviewTargetPicker(BuildContext context) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) {
      return;
    }

    final targets = await _loadReviewTargets(currentUserId);
    if (!context.mounted || targets.isEmpty) {
      return;
    }

    final selectedTarget = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Кому залишити відгук', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...targets.map((target) {
                final bool reviewed = target['reviewed'] == true;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: bgTurquoiseLight,
                    backgroundImage: target['photoUrl'] != null ? NetworkImage(target['photoUrl']) : null,
                    child: target['photoUrl'] == null ? Icon(Icons.person, color: primaryTurquoise) : null,
                  ),
                  title: Text(target['name'] as String),
                  subtitle: Text(reviewed ? 'Відгук вже залишено' : 'Доступно для оцінки'),
                  trailing: reviewed
                      ? Icon(Icons.check_circle, color: Colors.green.shade600)
                      : const Icon(Icons.chevron_right),
                  onTap: reviewed ? null : () => Navigator.pop(context, target),
                );
              }),
            ],
          ),
        );
      },
    );

    if (!context.mounted || selectedTarget == null) {
      return;
    }

    final String role = trip.driverId == currentUserId ? 'driver' : 'passenger';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          tripId: trip.id,
          fromUserId: currentUserId,
          toUserId: selectedTarget['id'] as String,
          toUserName: selectedTarget['name'] as String,
          toUserPhotoUrl: selectedTarget['photoUrl'] as String?,
          role: role,
        ),
      ),
    );
  }
}