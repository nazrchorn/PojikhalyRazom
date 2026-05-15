import 'car.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final double rating;
  final List<Car> cars; // Змінили на список автомобілів
  final DateTime createdAt;
  final String? photoUrl;
  final String gender;
  final int tripsCompleted;

  // ✅ Нові поля для профілю
  final DateTime? birthDate; // Дата народження
  final bool isTalkative; // true - любить балакати, false - мовчазний
  final String musicType;  // напр. "speakers" або "headphones"
  final bool isSmoker;
  final bool allowSmoking;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.rating,
    this.cars = const [], // Пустий список як дефолт
    required this.createdAt,
    this.photoUrl,
    this.tripsCompleted = 0,
    required this.gender,
    this.birthDate,
    this.isTalkative = false,
    this.musicType = "headphones",
    this.isSmoker = false,
    this.allowSmoking = false,
  });

  /// Розраховує вік з дати народження
  int? getAge() {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  /// Повертає перший автомобіль (для зворотної сумісності)
  Car? get car => cars.isNotEmpty ? cars.first : null;

  factory User.fromMap(String id, Map<String, dynamic> map) {
    return User(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      tripsCompleted: map['tripsCompleted'] ?? 0,
      cars: (map['cars'] is List)
          ? (map['cars'] as List).map((c) => Car.fromMap(c)).toList()
          : (map['car'] != null ? [Car.fromMap(map['car'])] : []),
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      photoUrl: map['photoUrl'],
      gender: map['gender'] ?? 'Чоловік',
      birthDate: (map['birthDate'] is Timestamp)
          ? (map['birthDate'] as Timestamp).toDate()
          : null,
      isTalkative: map['isTalkative'] ?? false,
      musicType: map['musicType'] ?? "headphones",
      isSmoker: map['isSmoker'] ?? false,
      allowSmoking: map['allowSmoking'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'rating': rating,
      'tripsCompleted': tripsCompleted,
      'cars': cars.map((c) => c.toMap()).toList(),
      'createdAt': createdAt,
      'photoUrl': photoUrl,
      'gender': gender,
      'birthDate': birthDate,
      'isTalkative': isTalkative,
      'musicType': musicType,
      'isSmoker': isSmoker,
      'allowSmoking': allowSmoking,
    };
  }
}