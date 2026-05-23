import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/booking_request.dart';
import '../models/trip.dart';
import '../models/location.dart';
import '../main.dart';
import 'pickup_dropoff_location_screen.dart';
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
  Map<String, dynamic>? _draftPickupPoint;
  Map<String, dynamic>? _draftDropoffPoint;

  bool get _hasPendingStopPointChanges =>
      _draftPickupPoint != null || _draftDropoffPoint != null;

  String? _effectivePickupAddress(BookingRequest request) {
    return (_draftPickupPoint?['address'] as String?) ?? request.pickupAddress;
  }

  String? _effectiveDropoffAddress(BookingRequest request) {
    return (_draftDropoffPoint?['address'] as String?) ?? request.dropoffAddress;
  }

  LatLng? _effectivePickupLatLng(BookingRequest request) {
    if (_draftPickupPoint != null) {
      return LatLng(
        (_draftPickupPoint!['lat'] as num).toDouble(),
        (_draftPickupPoint!['lng'] as num).toDouble(),
      );
    }
    if (request.pickupLat != null && request.pickupLng != null) {
      return LatLng(request.pickupLat!, request.pickupLng!);
    }
    return null;
  }

  LatLng? _effectiveDropoffLatLng(BookingRequest request) {
    if (_draftDropoffPoint != null) {
      return LatLng(
        (_draftDropoffPoint!['lat'] as num).toDouble(),
        (_draftDropoffPoint!['lng'] as num).toDouble(),
      );
    }
    if (request.dropoffLat != null && request.dropoffLng != null) {
      return LatLng(request.dropoffLat!, request.dropoffLng!);
    }
    return null;
  }

  String _normalizeCity(String city) {
    return city.split(',').first.trim().toLowerCase();
  }

  int _findCityIndex(List<String> orderedCities, String? city) {
    if (city == null || city.trim().isEmpty) return -1;
    final normalized = _normalizeCity(city);
    for (int i = 0; i < orderedCities.length; i++) {
      final routeCity = _normalizeCity(orderedCities[i]);
      if (routeCity == normalized || routeCity.contains(normalized) || normalized.contains(routeCity)) {
        return i;
      }
    }
    return -1;
  }

  Location _resolveLocationForCity(Trip trip, String city) {
    final route = <Location>[trip.origin, ...trip.stops, trip.destination];
    final normalized = _normalizeCity(city);
    for (final point in route) {
      final routeCity = _normalizeCity(point.city);
      if (routeCity == normalized || routeCity.contains(normalized) || normalized.contains(routeCity)) {
        return point;
      }
    }
    return route.first;
  }

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

  Future<void> _acknowledgeDriverUpdate(BookingRequest request) async {
    if (_actionInProgress) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid != request.passengerId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Підтвердити зміни може тільки пасажир цього запиту')),
      );
      return;
    }

    setState(() => _actionInProgress = true);
    try {
      final passengerData = await _userService.loadUserData(request.passengerId);
      final passengerName = passengerData?['name'] as String? ?? 'Пасажир';
      await _bookingService.acknowledgeRequestUpdateByPassenger(
        requestId: request.id,
        passengerName: passengerName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Зміни підтверджено. Бронювання оформлено.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося підтвердити зміни: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      }
    }
  }

  Future<void> _cancelRequestByPassenger(BookingRequest request) async {
    if (_actionInProgress) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid != request.passengerId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Скасувати може тільки пасажир цього запиту')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Скасувати запит?'),
        content: const Text('Після скасування потрібно буде створити новий запит на бронювання.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ні'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Так', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionInProgress = true);
    try {
      await _bookingService.cancelRequestByPassenger(
        requestId: request.id,
        passengerId: currentUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запит скасовано')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося скасувати: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      }
    }
  }

  Future<void> _editStopPoint({
    required Trip trip,
    required BookingRequest request,
    required bool isPickup,
  }) async {
    if (_actionInProgress) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid != request.driverId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Змінювати точки може тільки водій цієї поїздки')),
      );
      return;
    }

    final String defaultCity = isPickup
        ? (request.fromCity ?? trip.origin.city)
        : (request.toCity ?? trip.destination.city);
    final Location initialFocus = _resolveLocationForCity(trip, defaultCity);

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PickupDropoffLocationScreen(
          tripOrigin: trip.origin,
          tripDestination: trip.destination,
          initialFocusLocation: initialFocus,
          isPickup: isPickup,
          defaultCity: defaultCity,
          apiKey: MyApp.orsKey,
        ),
      ),
    );
    if (!mounted || result == null) return;

    setState(() {
      final point = <String, dynamic>{
        'lat': result['latitude'] as double,
        'lng': result['longitude'] as double,
        'address': result['address'] as String,
      };
      if (isPickup) {
        _draftPickupPoint = point;
      } else {
        _draftDropoffPoint = point;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPickup
              ? 'Нова точка посадки збережена. Надішліть зміни пасажиру.'
              : 'Нова точка висадки збережена. Надішліть зміни пасажиру.',
        ),
      ),
    );
  }

  Future<void> _sendStopPointChangesToPassenger(BookingRequest request) async {
    if (_actionInProgress || !_hasPendingStopPointChanges) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid != request.driverId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Надсилати зміни може тільки водій цієї поїздки')),
      );
      return;
    }

    setState(() => _actionInProgress = true);
    try {
      await _bookingService.updateRequestStopPointsByDriver(
        requestId: request.id,
        pickup: _draftPickupPoint,
        dropoff: _draftDropoffPoint,
      );
      if (!mounted) return;

      setState(() {
        _draftPickupPoint = null;
        _draftDropoffPoint = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Зміни точок надіслано пасажиру одним запитом на погодження'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося надіслати зміни: $e')),
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

    final effectivePickup = _effectivePickupLatLng(request);
    final effectiveDropoff = _effectiveDropoffLatLng(request);

    if (effectivePickup != null) {
      markers.add(
        Marker(
          point: effectivePickup,
          width: 46,
          height: 46,
          child: const Icon(Icons.location_on, color: Colors.blue, size: 38),
        ),
      );
    }

    if (effectiveDropoff != null) {
      markers.add(
        Marker(
          point: effectiveDropoff,
          width: 46,
          height: 46,
          child: const Icon(Icons.flag_circle, color: Color(0xFF1F6F66), size: 34),
        ),
      );
    }

    final List<String> routeCities = <String>[trip.origin.city, ...trip.stops.map((s) => s.city), trip.destination.city];
    final int fromIdx = _findCityIndex(routeCities, request.fromCity);
    final int toIdx = _findCityIndex(routeCities, request.toCity);
    final bool hasFromStop = fromIdx > 0 && (fromIdx - 1) < trip.stops.length;
    final bool hasToStop = toIdx > 0 && toIdx < routeCities.length - 1 && (toIdx - 1) < trip.stops.length;
    final LatLng segmentFocus = hasFromStop
        ? LatLng(trip.stops[fromIdx - 1].lat, trip.stops[fromIdx - 1].lng)
        : hasToStop
            ? LatLng(trip.stops[toIdx - 1].lat, trip.stops[toIdx - 1].lng)
            : LatLng(trip.origin.lat, trip.origin.lng);

    final LatLng initialCenter = effectivePickup ?? effectiveDropoff ?? segmentFocus;

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

              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              final isDriverView = currentUid == request.driverId;
              final isPassengerView = currentUid == request.passengerId;
              final canAct = request.status == 'pending' && isDriverView;
              final bool hasPickupPoint =
                  (_effectivePickupAddress(request)?.trim().isNotEmpty ?? false) ||
                  (_effectivePickupLatLng(request) != null);
              final bool hasDropoffPoint =
                  (_effectiveDropoffAddress(request)?.trim().isNotEmpty ?? false) ||
                  (_effectiveDropoffLatLng(request) != null);
              final bool hasDriverUpdate = request.updatedByDriverAt != null;
              final bool waitingPassengerDecision =
                  hasDriverUpdate &&
                  request.status == 'pending' &&
                  (request.passengerAcknowledgedAt == null ||
                      request.passengerAcknowledgedAt!.isBefore(request.updatedByDriverAt!));
              final bool passengerNeedsToReviewUpdate =
                  hasDriverUpdate &&
                  request.status == 'pending' &&
                  isPassengerView &&
                  (request.passengerAcknowledgedAt == null ||
                      request.passengerAcknowledgedAt!.isBefore(request.updatedByDriverAt!));

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
                    if (_effectivePickupAddress(request) != null)
                      Text(
                        _draftPickupPoint != null
                            ? 'Посадка (нова): ${_effectivePickupAddress(request)}'
                            : 'Посадка: ${_effectivePickupAddress(request)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    if (_effectiveDropoffAddress(request) != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _draftDropoffPoint != null
                              ? 'Висадка (нова): ${_effectiveDropoffAddress(request)}'
                              : 'Висадка: ${_effectiveDropoffAddress(request)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    if (isDriverView && _hasPendingStopPointChanges) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7F4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryTurquoise.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'Є локально збережені зміни точок. Пасажир отримає один запит тільки після кнопки "Надіслати зміни пасажиру".',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (passengerNeedsToReviewUpdate) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7F4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryTurquoise.withValues(alpha: 0.35)),
                        ),
                        child: const Text(
                          'Водій оновив точку на карті. Перевірте мінікарту та підтвердьте зміни або скасуйте запит.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _actionInProgress ? null : () => _acknowledgeDriverUpdate(request),
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: const Text('Підтвердити нову точку', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTurquoise,
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _actionInProgress ? null : () => _cancelRequestByPassenger(request),
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                        label: const Text('Скасувати запит', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (canAct && (hasPickupPoint || hasDropoffPoint)) ...[
                      if (hasPickupPoint)
                        OutlinedButton.icon(
                          onPressed: _actionInProgress
                              ? null
                              : () => _editStopPoint(trip: trip, request: request, isPickup: true),
                          icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                          label: const Text('Перевибрати точку посадки'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            foregroundColor: primaryTurquoise,
                            side: BorderSide(color: primaryTurquoise.withValues(alpha: 0.45)),
                          ),
                        ),
                      if (hasPickupPoint && hasDropoffPoint) const SizedBox(height: 8),
                      if (hasDropoffPoint)
                        OutlinedButton.icon(
                          onPressed: _actionInProgress
                              ? null
                              : () => _editStopPoint(trip: trip, request: request, isPickup: false),
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: const Text('Перевибрати точку висадки'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            foregroundColor: primaryTurquoise,
                            side: BorderSide(color: primaryTurquoise.withValues(alpha: 0.45)),
                          ),
                        ),
                      if (_hasPendingStopPointChanges) ...[
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _actionInProgress
                              ? null
                              : () => _sendStopPointChangesToPassenger(request),
                          icon: const Icon(Icons.send_rounded, color: Colors.white),
                          label: const Text(
                            'Надіслати зміни пасажиру',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryTurquoise,
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                    ],
                    if (isDriverView && waitingPassengerDecision)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: const Text(
                          'Ви оновили точку. Тепер очікується згода пасажира. Після відмови запит скасується автоматично, після згоди — підтвердиться без дій водія.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      )
                    else if (!canAct)
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
                    else if (!waitingPassengerDecision)
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

