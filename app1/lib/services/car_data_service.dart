import 'dart:convert';
import 'package:flutter/services.dart';

/// Сервіс для управління даними про автомобілі (марки, моделі, кольори)
/// В майбутньому можна розширити для роботи з API
class CarDataService {
  static final CarDataService _instance = CarDataService._internal();

  factory CarDataService() {
    return _instance;
  }

  CarDataService._internal();

  Map<String, dynamic>? _cachedData;

  /// Завантажує дані про марки, моделі та кольори автомобілів
  Future<Map<String, dynamic>> loadCarData() async {
    if (_cachedData != null) {
      return _cachedData!;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/car_brands.json');
      _cachedData = jsonDecode(jsonString);
      return _cachedData!;
    } catch (e) {
      throw Exception('Помилка завантаження даних про автомобілі: $e');
    }
  }

  /// Отримує список усіх доступних марок
  Future<List<String>> getBrands() async {
    final data = await loadCarData();
    final brands = data['brands'] as List?;
    return brands?.map((b) => b['name'].toString()).toList() ?? [];
  }

  /// Отримує моделі для конкретної марки
  Future<List<String>> getModelsForBrand(String brand) async {
    final data = await loadCarData();
    final brands = data['brands'] as List?;
    final brandData = brands?.firstWhere(
      (b) => b['name'] == brand,
      orElse: () => null,
    );
    if (brandData == null) return [];
    return List<String>.from(brandData['models'] ?? []);
  }

  /// Отримує список доступних кольорів
  Future<List<String>> getColors() async {
    final data = await loadCarData();
    return List<String>.from(data['colors'] ?? []);
  }

  /// Очищує кеш (корисно при оновленні даних)
  void clearCache() {
    _cachedData = null;
  }
}

