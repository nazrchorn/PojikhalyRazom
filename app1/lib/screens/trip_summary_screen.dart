import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'main_screen.dart';
import '../models/location.dart';
import '../models/trip.dart';

class TripSummaryScreen extends StatefulWidget {
  final String title;
  final Map<String, dynamic> origin;
  final Map<String, dynamic> destination;
  final Map<String, dynamic> selectedRoute;
  final List<Map<String, dynamic>> selectedStops;

  const TripSummaryScreen({
    super.key,
    required this.title,
    required this.origin,
    required this.destination,
    required this.selectedRoute,
    required this.selectedStops,
  });

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  // Основні параметри (збігаються з назвами в коді нижче)
  int seats = 3;
  double price = 50;
  DateTime? departureTime;

  // Фільтри поїздки
  bool allowChildren = true;
  bool allowPets = false;
  bool womenOnly = false;

  // Вподобання водія
  bool isTalkative = false;
  String musicType = "headphones";
  bool isSmoker = false;
  bool allowSmoking = false;

  String? driverGender;
  List<Map<String, dynamic>> stops = [];
  List<Map<String, dynamic>> suggestedStops = [];

  final Color _primaryTeal = const Color(0xFF00BFA5);

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
    stops = List.from(widget.selectedStops);
  }

  Future<void> _loadDriverProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        driverGender = data['gender'];
        isTalkative = data['isTalkative'] ?? false;
        musicType = data['musicType'] ?? "headphones";
        isSmoker = data['isSmoker'] ?? false;
        allowSmoking = data['allowSmoking'] ?? false;
      });
    }
  }

  Future<void> _saveTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Будь ласка, оберіть дату та час виїзду")),
      );
      return;
    }

    // 1. Формуємо об'єкти локацій
    final originLocation = Location(
      city: widget.origin['city'] ?? "Невідомо",
      countryCode: widget.origin['country'] ?? "UA",
      lat: (widget.origin['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (widget.origin['lng'] as num?)?.toDouble() ?? 0.0,
    );

    final destinationLocation = Location(
      city: widget.destination['city'] ?? "Невідомо",
      countryCode: widget.destination['country'] ?? "UA",
      lat: (widget.destination['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (widget.destination['lng'] as num?)?.toDouble() ?? 0.0,
    );

    // 2. Індексований список міст для пошуку (toLowerCase)
    final List<String> routeCities = [
      originLocation.city.toLowerCase().trim(),
      ...stops.map((s) => (s['city'] as String).toLowerCase().trim()),
      destinationLocation.city.toLowerCase().trim(),
    ];

    // 3. Формуємо об'єкт Trip для відправки
    final trip = Trip(
      id: '', // Firestore сам згенерує ID
      driverId: user.uid,
      origin: originLocation,
      destination: destinationLocation,
      departureTime: departureTime!,
      availableSeats: seats,
      pricePerSeat: price,
      passengers: [],
      routeCities: routeCities,
      createdAt: DateTime.now(),
      stops: stops.map((s) => Location(
        city: s['city'],
        countryCode: s['country'] ?? "UA",
        lat: (s['lat'] as num).toDouble(),
        lng: (s['lng'] as num).toDouble(),
      )).toList(),
      allowChildren: allowChildren,
      allowPets: allowPets,
      womenOnly: womenOnly,
      // Додаємо routeCities в toMap всередині моделі Trip пізніше,
      // або додаємо вручну нижче
    );

    try {
      final Map<String, dynamic> tripMap = trip.toMap();
      tripMap['routeCities'] = routeCities; // Додаємо індекс для пошуку

      await FirebaseFirestore.instance.collection('trips').add(tripMap);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Поїздку успішно опубліковано!"),
            backgroundColor: Color(0xFF5DD9C1),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 1)),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint("❌ Error saving trip: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Помилка: $e")),
        );
      }
    }
  }

  String _formatDuration(double seconds) {
    final totalMinutes = (seconds / 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return hours > 0 ? "$hours год ${minutes} хв" : "$minutes хв";
  }

  @override
  Widget build(BuildContext context) {
    final durationText = _formatDuration((widget.selectedRoute['duration'] ?? 0).toDouble());
    final distanceKm = ((widget.selectedRoute['distance'] ?? 0) / 1000).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Підсумок поїздки"),
        backgroundColor: _primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // КАРТКА МАРШРУТУ
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, color: _primaryTeal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${widget.origin['city']} ➔ ${widget.destination['city']}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text("Відправлення: ${widget.origin['address']}", style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 4),
                  Text("Прибуття: ${widget.destination['address']}", style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _primaryTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("⏱ $durationText • 📏 $distanceKm км",
                        style: TextStyle(color: _primaryTeal, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 32),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _primaryTeal.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.calendar_month, color: _primaryTeal),
                    ),
                    title: const Text("Дата та час виїзду", style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      departureTime != null
                          ? "${departureTime!.day}.${departureTime!.month}.${departureTime!.year} о ${departureTime!.hour.toString().padLeft(2, '0')}:${departureTime!.minute.toString().padLeft(2, '0')}"
                          : "Натисніть, щоб обрати",
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                        builder: (context, child) => Theme(
                          data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: _primaryTeal)),
                          child: child!,
                        ),
                      );
                      if (date != null && mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          builder: (context, child) => Theme(
                            data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: _primaryTeal)),
                            child: child!,
                          ),
                        );
                        if (time != null) {
                          setState(() {
                            departureTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // КАРТКА ДЕТАЛЕЙ (МІСЦЯ, ЦІНА)
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Кількість місць", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: _primaryTeal,
                            onPressed: () => setState(() { if (seats > 1) seats--; }),
                          ),
                          Text("$seats", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: _primaryTeal,
                            onPressed: () => setState(() { if (seats < 8) seats++; }),
                          ),
                        ],
                      )
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Ціна за місце", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            suffixText: "грн",
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryTeal)),
                          ),
                          onChanged: (val) {
                            setState(() {
                              price = double.tryParse(val) ?? price;
                            });
                          },
                          controller: TextEditingController(text: price.toStringAsFixed(0))..selection = TextSelection.fromPosition(TextPosition(offset: price.toStringAsFixed(0).length)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ЗУПИНКИ
          if (stops.isNotEmpty)
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Вибрані зупинки:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: stops.map((stop) => Chip(
                        label: Text(stop['city']),
                        backgroundColor: _primaryTeal.withOpacity(0.15),
                        onDeleted: () => setState(() => stops.removeWhere((s) => s['city'] == stop['city'])),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ПРАВИЛА
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: _primaryTeal,
                  title: const Text("Пасажири: Тільки жінки"),
                  secondary: const Icon(Icons.female),
                  value: womenOnly,
                  onChanged: (val) => setState(() => womenOnly = val),
                ),
                SwitchListTile(
                  activeColor: _primaryTeal,
                  title: const Text("Можна з дітьми"),
                  secondary: const Icon(Icons.child_care),
                  value: allowChildren,
                  onChanged: (val) => setState(() => allowChildren = val),
                ),
                SwitchListTile(
                  activeColor: _primaryTeal,
                  title: const Text("Можна з тваринами"),
                  secondary: const Icon(Icons.pets),
                  value: allowPets,
                  onChanged: (val) => setState(() => allowPets = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // АТМОСФЕРА
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: _primaryTeal,
                  title: Text(isTalkative ? "Люблю поговорити" : "Мовчазний у дорозі"),
                  secondary: Icon(isTalkative ? Icons.forum : Icons.speaker_notes_off),
                  value: isTalkative,
                  onChanged: (val) => setState(() => isTalkative = val),
                ),
                ListTile(
                  leading: const Icon(Icons.music_note, color: Colors.grey), // Виправлено тут
                  title: const Text("Музика в салоні"),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: "silence", icon: Icon(Icons.volume_off)),
                      ButtonSegment(value: "music", icon: Icon(Icons.music_note)),
                    ],
                    selected: {musicType},
                    onSelectionChanged: (val) => setState(() => musicType = val.first),
                  ),
                ),
                SwitchListTile(
                  activeColor: _primaryTeal,
                  title: Text(isSmoker ? "Я палю" : "Не палю"),
                  secondary: const Icon(Icons.smoking_rooms),
                  value: isSmoker,
                  onChanged: (val) => setState(() => isSmoker = val),
                ),
                SwitchListTile(
                  activeColor: _primaryTeal,
                  title: const Text("Можна палити пасажирам"),
                  secondary: const Icon(Icons.smoke_free),
                  value: allowSmoking,
                  onChanged: (val) => setState(() => allowSmoking = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _saveTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Опублікувати поїздку", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}