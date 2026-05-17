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

  final Color primaryTurquoise = const Color(0xFF1F6F66);

  @override
  void initState() {
    super.initState();
    _fromCity = widget.from;
    _toCity = widget.to;
    _selectedDate = DateTime.now();
  }

  Future<void> _selectSingleDate() async {
    final scheme = Theme.of(context).colorScheme;
    final datePickerScheme = scheme.copyWith(
      primary: const Color(0xFF1F6F66),
      secondary: const Color(0xFF1F6F66),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: datePickerScheme,
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: const Color(0xFF1F6F66),
              headerForegroundColor: Colors.white,
              todayBorder: BorderSide(color: const Color(0xFF1F6F66)),
            ),
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
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color fieldBg = dark ? const Color(0xFF23453E) : const Color(0xFFF4F6F6);
    final Color fieldBorder = dark ? const Color(0xFF3F7C71) : const Color(0xFFD7DDDD);

    return InkWell(
      onTap: () => _selectCity(isFrom),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: fieldBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fieldBorder),
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
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color accentGreen = dark ? const Color(0xFF2A5C55) : const Color(0xFF1F6F66);
    final Color dateBg = dark ? const Color(0xFF23453E) : const Color(0xFFF4F6F6);
    final Color dateBorder = dark ? const Color(0xFF3F7C71) : const Color(0xFFD7DDDD);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Пошук поїздок'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Theme.of(context).appBarTheme.surfaceTintColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
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
                    color: Theme.of(context).cardColor,
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
                            color: dateBg,
                           borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: dateBorder),
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
                                    color: _selectedDate != null
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Theme.of(context).hintColor,
                                 ),
                               ),
                             ),
                              Icon(Icons.arrow_drop_down_rounded,
                                  color: Theme.of(context).hintColor),
                           ],
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
               const SizedBox(height: 20),
               ElevatedButton(
                onPressed: _onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGreen,
                  foregroundColor: const Color(0xFFF1FBF8),
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