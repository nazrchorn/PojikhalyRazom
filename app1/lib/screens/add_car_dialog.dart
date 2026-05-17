import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/car.dart';

class CarBrandsData {
  final List<Map<String, dynamic>> brands;
  final List<String> colors;

  CarBrandsData({required this.brands, required this.colors});

  factory CarBrandsData.fromJson(Map<String, dynamic> json) {
    return CarBrandsData(
      brands: List<Map<String, dynamic>>.from(json['brands'] ?? []),
      colors: List<String>.from(json['colors'] ?? []),
    );
  }
}

class AddCarDialog extends StatefulWidget {
  const AddCarDialog({super.key});

  @override
  State<AddCarDialog> createState() => _AddCarDialogState();
}

class _AddCarDialogState extends State<AddCarDialog> {
  final Color primaryTurquoise = const Color(0xFF1F6F66);
  final Color bgTurquoiseLight = const Color(0xFFE8F8F5);

  int currentStep = 0;
  late TextEditingController brandController;
  late TextEditingController modelController;
  late TextEditingController colorController;
  int? selectedYear;
  int? selectedSeats;

  CarBrandsData? carData;
  List<String> filteredModels = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    brandController = TextEditingController();
    modelController = TextEditingController();
    colorController = TextEditingController();
    selectedYear = DateTime.now().year;
    selectedSeats = 4;
    _loadCarData();
  }

  Future<void> _loadCarData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/car_brands.json');
      final jsonData = jsonDecode(jsonString);
      setState(() {
        carData = CarBrandsData.fromJson(jsonData);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Помилка завантаження JSON: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    brandController.dispose();
    modelController.dispose();
    colorController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (currentStep == 0 && brandController.text.isEmpty) {
      _showError("Виберіть марку");
      return;
    }
    if (currentStep == 1 && modelController.text.isEmpty) {
      _showError("Введіть модель");
      return;
    }

    if (currentStep < 3) {
      setState(() => currentStep++);
    } else {
      _saveCar();
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _saveCar() {
    final newCar = Car(
      brand: brandController.text,
      model: modelController.text,
      year: selectedYear ?? DateTime.now().year,
      seats: selectedSeats ?? 4,
      color: colorController.text.isNotEmpty ? colorController.text : null,
    );

    Navigator.pop(context, newCar);
  }

  List<String> _getAvailableBrands() {
    if (carData == null) return [];
    return carData!.brands.map((b) => b['name'] as String).toList();
  }

  List<String> _getModelsForBrand(String brand) {
    if (carData == null) return [];
    final brandData =
        carData!.brands.firstWhere((b) => b['name'] == brand, orElse: () => {});
    if (brandData.isEmpty) return [];
    return List<String>.from(brandData['models'] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: CircularProgressIndicator(color: primaryTurquoise),
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Прогрес індикатор ---
                Row(
                  children: List.generate(
                    4,
                    (index) => Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index <= currentStep
                              ? primaryTurquoise
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- Назва кроку ---
                Text(
                  _getStepTitle(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _getStepDescription(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // --- Вміст кожного кроку ---
                _buildStepContent(),
                const SizedBox(height: 32),

                // --- Кнопки навігації ---
                Row(
                  children: [
                    if (currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Назад'),
                        ),
                      ),
                    if (currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTurquoise,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          currentStep < 3 ? 'Далі' : 'Додати авто',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (currentStep) {
      case 0:
        return 'Марка автомобіля';
      case 1:
        return 'Модель';
      case 2:
        return 'Колір і рік';
      case 3:
        return 'Кількість місць';
      default:
        return '';
    }
  }

  String _getStepDescription() {
    switch (currentStep) {
      case 0:
        return 'Виберіть марку з пропозицій';
      case 1:
        return 'Виберіть модель для ${brandController.text}';
      case 2:
        return 'Виберіть колір та рік випуску';
      case 3:
        return 'Скільки пасажирських місць?';
      default:
        return '';
    }
  }

  Widget _buildStepContent() {
    switch (currentStep) {
      case 0:
        return _buildBrandStep();
      case 1:
        return _buildModelStep();
      case 2:
        return _buildColorYearStep();
      case 3:
        return _buildSeatsStep();
      default:
        return const SizedBox();
    }
  }

  // --- Крок 1: Марка ---
  Widget _buildBrandStep() {
    final availableBrands = _getAvailableBrands();
    final filteredBrands = brandController.text.isEmpty
        ? availableBrands
        : availableBrands
            .where((b) =>
                b.toLowerCase().contains(brandController.text.toLowerCase()))
            .toList();

    return Column(
      children: [
        TextField(
          controller: brandController,
          decoration: InputDecoration(
            hintText: 'Введіть або виберіть марку...',
            prefixIcon: Icon(Icons.directions_car, color: primaryTurquoise),
            suffixIcon: brandController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => brandController.clear()),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          onChanged: (value) => setState(() {}),
        ),
        if (filteredBrands.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredBrands.length,
              itemBuilder: (context, index) {
                final brand = filteredBrands[index];
                return ListTile(
                  leading: Icon(Icons.directions_car_filled,
                      color: primaryTurquoise, size: 18),
                  title: Text(brand),
                  onTap: () {
                    setState(() {
                      brandController.text = brand;
                      modelController.clear();
                      filteredModels = _getModelsForBrand(brand);
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // --- Крок 2: Модель ---
  Widget _buildModelStep() {
    filteredModels = _getModelsForBrand(brandController.text);
    final filtered = modelController.text.isEmpty
        ? filteredModels
        : filteredModels
            .where((m) =>
                m.toLowerCase().contains(modelController.text.toLowerCase()))
            .toList();

    return Column(
      children: [
        TextField(
          controller: modelController,
          decoration: InputDecoration(
            hintText: 'Введіть або виберіть модель...',
            prefixIcon: Icon(Icons.label, color: primaryTurquoise),
            suffixIcon: modelController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => modelController.clear()),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          textCapitalization: TextCapitalization.characters,
          onChanged: (value) => setState(() {}),
        ),
        if (filtered.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final model = filtered[index];
                return ListTile(
                  title: Text(model),
                  trailing: Icon(Icons.check_circle_outline,
                      color: primaryTurquoise, size: 18),
                  onTap: () {
                    setState(() {
                      modelController.text = model;
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // --- Крок 3: Колір і рік ---
  Widget _buildColorYearStep() {
    final availableColors = carData?.colors ?? [];
    final filteredColors = colorController.text.isEmpty
        ? availableColors
        : availableColors
            .where((c) =>
                c.toLowerCase().contains(colorController.text.toLowerCase()))
            .toList();

    return Column(
      children: [
        // Колір
        TextField(
          controller: colorController,
          decoration: InputDecoration(
            hintText: 'Виберіть або введіть колір...',
            prefixIcon: Icon(Icons.palette, color: primaryTurquoise),
            suffixIcon: colorController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => colorController.clear()),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          onChanged: (value) => setState(() {}),
        ),
        if (filteredColors.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredColors.length,
              itemBuilder: (context, index) {
                final color = filteredColors[index];
                return ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _getColorFromString(color),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                  title: Text(color),
                  onTap: () {
                    setState(() {
                      colorController.text = color;
                    });
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 16),

        // Рік
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: primaryTurquoise),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<int>(
                  value: selectedYear,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: List.generate(35, (i) => DateTime.now().year - i)
                      .map((year) => DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => selectedYear = value);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Крок 4: Місця ---
  Widget _buildSeatsStep() {
    return Column(
      children: [
        Text(
          'Пасажирських місць: ${selectedSeats ?? 4}',
          style:
              const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape:
                RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 4),
            activeTrackColor: primaryTurquoise,
            inactiveTrackColor: Colors.grey.shade200,
            valueIndicatorColor: primaryTurquoise,
          ),
          child: Slider(
            value: (selectedSeats ?? 4).toDouble(),
            min: 1,
            max: 9,
            divisions: 8,
            label: '${selectedSeats ?? 4}',
            onChanged: (value) {
              setState(() => selectedSeats = value.toInt());
            },
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            9,
            (index) => GestureDetector(
              onTap: () => setState(() => selectedSeats = index + 1),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selectedSeats == index + 1
                      ? primaryTurquoise
                      : bgTurquoiseLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selectedSeats == index + 1
                        ? primaryTurquoise
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: selectedSeats == index + 1
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getColorFromString(String colorName) {
    final colorMap = {
      'Чорний': Colors.black,
      'Білий': Colors.white,
      'Сірий': Colors.grey,
      'Срібний': const Color(0xFFC0C0C0),
      'Червоний': Colors.red,
      'Темно-червоний': const Color(0xFF8B0000),
      'Синій': Colors.blue,
      'Темно-синій': const Color(0xFF00008B),
      'Світло-синій': Colors.lightBlue,
      'Зелений': Colors.green,
      'Темно-зелений': const Color(0xFF006400),
      'Жовтий': Colors.yellow,
      'Оранжевий': Colors.orange,
      'Коричневий': Colors.brown,
      'Бежевий': const Color(0xFFF5F5DC),
      'Жовто-зелений': const Color(0xFF9ACD32),
      'Фіолетовий': Colors.purple,
      'Золотий': const Color(0xFFFFD700),
      'Графіт': const Color(0xFF36454F),
    };
    return colorMap[colorName] ?? Colors.grey;
  }
}

