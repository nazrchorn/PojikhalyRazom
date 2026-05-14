import 'car.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final double rating;
  final Car? car;
  final DateTime createdAt;
  final String? photoUrl;
  final String gender;
  final int tripsCompleted;

  // ✅ Нові поля для профілю
  final int? age;
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
    this.car,
    required this.createdAt,
    this.photoUrl,
    this.tripsCompleted = 0,
    required this.gender,
    this.age,
    this.isTalkative = false,
    this.musicType = "headphones",
    this.isSmoker = false,
    this.allowSmoking = false,
  });

  factory User.fromMap(String id, Map<String, dynamic> map) {
    return User(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      tripsCompleted: map['tripsCompleted'] ?? 0,
      car: map['car'] != null ? Car.fromMap(map['car']) : null,
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      photoUrl: map['photoUrl'],
      gender: map['gender'] ?? 'male',
      // ✅ Мапимо нові поля
      age: map['age'],
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
      'car': car?.toMap(),
      'createdAt': createdAt,
      'photoUrl': photoUrl,
      'gender': gender,
      // ✅ Зберігаємо нові поля
      'age': age,
      'isTalkative': isTalkative,
      'musicType': musicType,
      'isSmoker': isSmoker,
      'allowSmoking': allowSmoking,
    };
  }
}