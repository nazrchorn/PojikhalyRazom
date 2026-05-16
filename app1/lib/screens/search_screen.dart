import 'package:flutter/material.dart';
import 'trips_list_screen.dart';
import 'city_search_screen.dart'; // Новий екран (див. нижче)

class SearchScreen extends StatefulWidget {
  final String from;
  final String to;

  const SearchScreen({
    super.key,
    required this.from,
    required this.to,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late String _fromCity;
  late String _toCity;
  DateTime? _selectedDate;
  DateTime? _dateRangeStart;
  DateTime? _dateRangeEnd;
  bool _allowSmoking = true;
  bool _allowPets = true;
  bool _allowChildren = true;

  final Color primaryTurquoise = const Color(0xFF2F8F7F);

  @override
  void initState() {
    super.initState();
    _fromCity = widget.from;
    _toCity = widget.to;
    _selectedDate = DateTime.now();
  }

  Future<void> _selectSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF2F8F7F),
          ),
          child: child ?? Container(),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Функція для відкриття екрану вибору міста
  Future<void> _selectCity(bool isFrom) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CitySearchScreen(
          title: isFrom ? 'Звідки їдемо?' : 'Куди прямуємо?',
        ),
      ),
    );

    // result тепер — це Map<String, dynamic>
    if (result != null && mounted) {
      setState(() {
        if (isFrom) {
          _fromCity = result['city']; // Беремо назву міста
          // Можеш також зберегти координати в змінні, якщо треба
        } else {
          _toCity = result['city'];
        }
      });
    }
  }

  void _onSearch() {
    if (_fromCity.isNotEmpty && _toCity.isNotEmpty && _selectedDate != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TripsListScreen(
            fromCity: _fromCity,
            toCity: _toCity,
            selectedDate: _selectedDate!,
            dateRangeStart: _dateRangeStart,
            dateRangeEnd: _dateRangeEnd,
            allowSmoking: _allowSmoking,
            allowPets: _allowPets,
            allowChildren: _allowChildren,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Будь ласка, оберіть міста і дату")),
      );
    }
  }

  Widget _buildCitySelector(String label, String value, IconData icon, bool isFrom) {
    final isEmpty = value.isEmpty;
    return InkWell(
      onTap: () => _selectCity(isFrom),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryTurquoise),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    isEmpty ? "Оберіть місто" : value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isEmpty ? FontWeight.normal : FontWeight.bold,
                      color: isEmpty ? Colors.grey : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FCFA),
      appBar: AppBar(
        title: const Text('Пошук поїздок'),
        backgroundColor: const Color(0xFFF4FBF9),
        surfaceTintColor: const Color(0xFFF4FBF9),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildCitySelector("Звідки", _fromCity, Icons.radio_button_checked, true),
              const SizedBox(height: 12),
              _buildCitySelector("Куди", _toCity, Icons.location_on, false),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Дата", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _selectSingleDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: primaryTurquoise),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedDate != null
                                    ? "${_selectedDate!.day}.${_selectedDate!.month}.${_selectedDate!.year}"
                                    : "Оберіть дату",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _selectedDate != null ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_drop_down_rounded, color: Colors.grey.shade500),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Фільтри", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: _allowSmoking,
                      onChanged: (val) => setState(() => _allowSmoking = val ?? true),
                      title: const Text("Дозвіл на паління", style: TextStyle(fontSize: 13)),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: _allowPets,
                      onChanged: (val) => setState(() => _allowPets = val ?? true),
                      title: const Text("З тваринами", style: TextStyle(fontSize: 13)),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: _allowChildren,
                      onChanged: (val) => setState(() => _allowChildren = val ?? true),
                      title: const Text("З дітьми", style: TextStyle(fontSize: 13)),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTurquoise,
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Знайти поїздки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}