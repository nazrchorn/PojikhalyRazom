import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/trip_service.dart';
import 'trip_details_screen.dart';

class TripsListScreen extends StatefulWidget {
  final String fromCity;
  final String toCity;
  final DateTime selectedDate;

  const TripsListScreen({
    super.key,
    required this.fromCity,
    required this.toCity,
    required this.selectedDate,
  });

  @override
  State<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends State<TripsListScreen> {
  late DateTime _currentDate;
  bool _allowPets = false;
  bool _allowChildren = false;

  final Color primaryTurquoise = const Color(0xFF2F8F7F);
  final TripService _tripService = TripService();

  @override
  void initState() {
    super.initState();
    _currentDate = widget.selectedDate;
  }

  // Допоміжна функція для очищення назви міста (Львів, Львівська обл -> Львів)
  String _cleanCityName(String city) {
    return city.split(',').first.toLowerCase().trim();
  }

  int _findCityIndex(List<String> routeCities, String city) {
    final normalized = _cleanCityName(city);
    return routeCities.indexWhere((item) => _cleanCityName(item) == normalized);
  }

  double _calculateSegmentPrice(Trip trip) {
    final routeCities = <String>[trip.origin.city, ...trip.stops.map((s) => s.city), trip.destination.city];
    if (routeCities.length < 2) return trip.pricePerSeat;

    final fromIdx = _findCityIndex(routeCities, widget.fromCity);
    final toIdx = _findCityIndex(routeCities, widget.toCity);
    final totalSegments = routeCities.length - 1;
    if (fromIdx < 0 || toIdx <= fromIdx || totalSegments <= 0) {
      return trip.pricePerSeat;
    }

    final ratio = ((toIdx - fromIdx) / totalSegments).clamp(0.25, 1.0);
    return (trip.pricePerSeat * ratio).roundToDouble();
  }

  void _previousDay() {
    setState(() {
      _currentDate = _currentDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      _currentDate = _currentDate.add(const Duration(days: 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final String cleanFrom = _cleanCityName(widget.fromCity);
    final String cleanTo = _cleanCityName(widget.toCity);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FCFA),
      appBar: AppBar(
        title: Text(
          "${widget.fromCity.split(',').first} → ${widget.toCity.split(',').first}",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: const Color(0xFFF4FBF9),
        surfaceTintColor: const Color(0xFFF4FBF9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // Навігація по датам
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousDay,
                  icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2F8F7F)),
                ),
                Column(
                  children: [
                    Text(
                      "${_currentDate.day.toString().padLeft(2, '0')}.${_currentDate.month.toString().padLeft(2, '0')}.${_currentDate.year}",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _getDayName(_currentDate),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _nextDay,
                  icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF2F8F7F)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Фільтри
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Фільтри", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFilterChip("З тваринами", _allowPets, (val) {
                      setState(() => _allowPets = val);
                    }),
                    _buildFilterChip("З дітьми", _allowChildren, (val) {
                      setState(() => _allowChildren = val);
                    }),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Список поїздок
          Expanded(
            child: StreamBuilder<List<Trip>>(
              stream: _tripService.getAllTrips(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Помилка завантаження даних"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF2F8F7F)));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final allTrips = snapshot.data!;

                 // Фільтрація з датою та фільтрами
                 final filteredTrips = allTrips.where((trip) {
                   final String tripOrigin = _cleanCityName(trip.origin.city);
                   final String tripDest = _cleanCityName(trip.destination.city);
                   final List<String> tripStops = trip.stops.map((s) => _cleanCityName(s.city)).toList();

                   final List<String> pickupPoints = [tripOrigin, ...tripStops];
                   final List<String> dropoffPoints = [...tripStops, tripDest];

                   bool matchFrom = pickupPoints.contains(cleanFrom);
                   bool matchTo = dropoffPoints.contains(cleanTo);

                   if (!matchFrom || !matchTo) {
                     return false;
                   }

                   final orderedRoute = <String>[trip.origin.city, ...trip.stops.map((s) => s.city), trip.destination.city];
                   final fromIdx = _findCityIndex(orderedRoute, widget.fromCity);
                   final toIdx = _findCityIndex(orderedRoute, widget.toCity);
                   if (!(fromIdx >= 0 && toIdx > fromIdx)) {
                     return false;
                   }

                   // Фільтрація по даті (поточна дата зі стану)
                   final tripDate = trip.departureTime;
                   final tripDateOnly = DateTime(tripDate.year, tripDate.month, tripDate.day);
                   final currentDateOnly = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
                   
                   if (tripDateOnly != currentDateOnly) {
                     return false;
                   }

                   // Фільтрація по параметрам
                   if (_allowPets && !trip.allowPets) return false;
                   if (_allowChildren && !trip.allowChildren) return false;

                   return true;
                 }).toList();

                if (filteredTrips.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: filteredTrips.length,
                  itemBuilder: (context, index) {
                    final trip = filteredTrips[index];
                    final segmentPrice = _calculateSegmentPrice(trip);
                    final hasDiscount = segmentPrice < trip.pricePerSeat;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripDetailScreen(
                              trip: trip,
                              showBookingButton: true,
                              bookingFromCity: widget.fromCity,
                              bookingToCity: widget.toCity,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${trip.departureTime.hour}:${trip.departureTime.minute.toString().padLeft(2, '0')}",
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      "${trip.departureTime.day.toString().padLeft(2, '0')}.${trip.departureTime.month.toString().padLeft(2, '0')}.${trip.departureTime.year}",
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F8F5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "${segmentPrice.toInt()} ₴",
                                        style: TextStyle(color: primaryTurquoise, fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                      if (hasDiscount)
                                        Text(
                                          "замість ${trip.pricePerSeat.toInt()} ₴",
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Column(
                                  children: [
                                    Icon(Icons.radio_button_checked, size: 14, color: primaryTurquoise),
                                    Container(width: 2, height: 20, color: Colors.grey.shade200),
                                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(trip.origin.city, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 14),
                                      Text(trip.destination.city, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.airline_seat_recline_normal_rounded, size: 18, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${trip.availableSeats} вільних місць",
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                                if (trip.womenOnly)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(8)),
                                    child: const Row(
                                      children: [
                                        Text("🌸 ", style: TextStyle(fontSize: 12)),
                                        Text("Тільки жінки", style: TextStyle(color: Colors.pink, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(DateTime date) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
    return days[date.weekday - 1];
  }

  Widget _buildFilterChip(String label, bool isSelected, Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2F8F7F) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2F8F7F) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const Text("Поїздок не знайдено", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Ми не знайшли поїздок за цим маршрутом. Спробуйте змінити назву міста або дату.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}