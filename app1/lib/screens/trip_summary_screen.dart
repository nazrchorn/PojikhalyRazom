import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  // Основні розрахункові параметри
  int seats = 1;
  int maxCarSeats = 4;
  double price = 0;
  double baseRecommendedPrice = 0; // Для порівняння з введеною ціною
  double fuelPrice = 75.31;
  DateTime? departureTime;

  final TextEditingController _priceController = TextEditingController();

  // Налаштування поїздки
  bool allowChildren = false;
  bool allowPets = false;
  bool womenOnly = false;
  bool isTalkative = false;
  String musicType = "headphones";
  bool isSmoker = false;
  bool allowSmoking = false;

  String? driverGender;
  List<Map<String, dynamic>> stops = [];
  final Color _primaryTeal = const Color(0xFF00BFA5);

  @override
  void initState() {
    super.initState();
    stops = List.from(widget.selectedStops);
    _loadDriverProfileAndCalculate();
  }

  Future<void> _loadDriverProfileAndCalculate() async {
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

        if (data['car'] != null && data['car']['seats'] != null) {
          maxCarSeats = data['car']['seats'];
          seats = maxCarSeats - 1; // За замовчуванням всі вільні місця
        }
      });
      _calculateFairPrice();
    }
  }

  void _calculateFairPrice() {
    double distanceKm = (widget.selectedRoute['distance'] ?? 0) / 1000;
    double consumption = 9.5;
    double totalTripFuelCost = (distanceKm * consumption / 100) * fuelPrice;

    // Стабільне ділення на 3 пасажирські місця
    double recommended = totalTripFuelCost / 3;
    double roundedPrice = (recommended / 5).round() * 5.0;

    setState(() {
      baseRecommendedPrice = roundedPrice > 49 ? roundedPrice : 50.0;
      price = baseRecommendedPrice;
      _priceController.text = price.toStringAsFixed(0);
    });
  }

  Future<void> _saveTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (departureTime == null) {
      _showSnackBar("Будь ласка, оберіть час виїзду");
      return;
    }

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

    final List<String> routeCities = [
      originLocation.city.toLowerCase().trim(),
      ...stops.map((s) => (s['city'] as String).toLowerCase().trim()),
      destinationLocation.city.toLowerCase().trim(),
    ];

    final trip = Trip(
      id: '',
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
    );

    try {
      final Map<String, dynamic> tripMap = trip.toMap();
      tripMap['routeCities'] = routeCities;
      await FirebaseFirestore.instance.collection('trips').add(tripMap);

      if (mounted) {
        _showSnackBar("Поїздку опубліковано!", isSuccess: true);
        Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 1)), (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = ((widget.selectedRoute['distance'] ?? 0) / 1000).toStringAsFixed(1);
    final durationText = _formatDuration((widget.selectedRoute['duration'] ?? 0).toDouble());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Ваша поїздка"),
        backgroundColor: _primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // БЛОК МАРШРУТУ
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${widget.origin['city']} → ${widget.destination['city']}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Відстань: $distanceKm км • В дорозі: $durationText",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _buildIconCircle(Icons.access_time_filled, true),
                  title: const Text("Коли вирушаємо?", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(departureTime != null
                      ? "${departureTime!.day}.${departureTime!.month} о ${departureTime!.hour}:${departureTime!.minute.toString().padLeft(2, '0')}"
                      : "Натисніть, щоб вибрати час"),
                  onTap: _pickDateTime,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // МІСЦЯ ТА ЦІНА
          _buildCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Вільних місць", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Row(
                      // Оновлений шматочок твого коду:
                        children: [
                          IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: _primaryTeal,
                              onPressed: () => setState(() { if (seats > 1) seats--; })
                          ),
                          Text("$seats", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              // ТУТ ПРИБРАЛИ "- 1"
                              color: seats < maxCarSeats ? _primaryTeal : Colors.grey,
                              onPressed: () {
                                // І ТУТ ТАКОЖ ПРИБРАЛИ "- 1"
                                if (seats < maxCarSeats) setState(() => seats++);
                              }
                          ),
                        ],
                    )
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Ціна за місце", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            (price <= baseRecommendedPrice + 150) ? "Оптимальна ціна" : "Ваша ціна",
                            style: TextStyle(
                                fontSize: 12,
                                color: (price <= baseRecommendedPrice + 150) ? Colors.green[600] : Colors.grey[600],
                                fontWeight: FontWeight.w500
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                            color: (price <= baseRecommendedPrice + 150) ? Colors.black : _primaryTeal),
                        decoration: const InputDecoration(suffixText: "грн"),
                        onChanged: (val) => setState(() => price = double.tryParse(val) ?? 0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // НАЛАШТУВАННЯ ТА АТМОСФЕРА
          _buildCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // 1. Тільки жінки (якщо водій жінка)
                _buildSwitchTile(
                    womenOnly ? "Тільки жінки" : "Для всіх пасажирів",
                    FontAwesomeIcons.venus,
                    womenOnly,
                        (v) => setState(() => womenOnly = v)
                ),

                // 2. Діти
                _buildSwitchTile(
                    allowChildren ? "Можна з дітьми" : "Без дітей",
                    FontAwesomeIcons.child,
                    allowChildren,
                        (v) => setState(() => allowChildren = v)
                ),

                // 3. Тварини
                _buildSwitchTile(
                    allowPets ? "З тваринами" : "Без тварин",
                    FontAwesomeIcons.paw,
                    allowPets,
                        (v) => setState(() => allowPets = v)
                ),
                const Divider(indent: 70),
                _buildSwitchTile(
                    isTalkative ? "Люблю поговорити" : "Мовчазний у дорозі",
                    isTalkative ? Icons.forum_rounded : Icons.speaker_notes_off_rounded,
                    isTalkative,
                        (v) => setState(() => isTalkative = v),
                    isFa: false
                ),

                // Музика
                ListTile(
                  leading: _buildIconCircle(
                      musicType == "music" ? Icons.music_note_rounded : Icons.volume_off_rounded,
                      musicType == "music"
                  ),
                  title: Text(musicType == "music" ? "Музика в салоні" : "Їду в тиші"),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: "silence", icon: Icon(Icons.volume_off, size: 20)),
                      ButtonSegment(value: "music", icon: Icon(Icons.music_note, size: 20)),
                    ],
                    selected: {musicType},
                    onSelectionChanged: (val) => setState(() => musicType = val.first),
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: _primaryTeal.withOpacity(0.2),
                        selectedForegroundColor: _primaryTeal
                    ),
                  ),
                ),

                // Власна звичка водія
                _buildSwitchTile(
                    isSmoker ? "Я палю" : "Не палю",
                    isSmoker ? Icons.smoking_rooms : Icons.smoke_free,
                    isSmoker,
                        (v) => setState(() => isSmoker = v),
                    isFa: false
                ),

                // ПРАВИЛО ДЛЯ ПАСАЖИРІВ (те, що ми забули)
                _buildSwitchTile(
                    allowSmoking ? "Можна палити в салоні" : "Палити в салоні заборонено",
                    allowSmoking ? Icons.check_circle_outline : Icons.block_flipped,
                    allowSmoking,
                        (v) => setState(() => allowSmoking = v),
                    isFa: false
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryTeal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            child: const Text("Опублікувати", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- Допоміжні методи для інтерфейсу ---

  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildIconCircle(dynamic icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? _primaryTeal.withOpacity(0.12) : Colors.grey.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: icon is IconData
          ? Icon(icon, color: isActive ? _primaryTeal : Colors.grey[500], size: 20)
          : FaIcon(icon as IconData, color: isActive ? _primaryTeal : Colors.grey[500], size: 18),
    );
  }

  Widget _buildSwitchTile(String title, dynamic icon, bool value, Function(bool) onChanged, {bool isFa = true}) {
    return SwitchListTile(
      activeColor: _primaryTeal,
      secondary: _buildIconCircle(icon, value),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      value: value,
      onChanged: onChanged,
    );
  }

  String _formatDuration(double seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? "$hours год $minutes хв" : "$minutes хв";
  }

  void _showSnackBar(String text, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isSuccess ? _primaryTeal : Colors.redAccent),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: _primaryTeal)), child: child!),
    );
    if (date != null) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) setState(() => departureTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
  }
}