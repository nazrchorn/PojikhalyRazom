import 'car.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;            // uid з Firebase Auth
  final String name;
  final String email;
  final String phone;
  final double rating;
  final Car? car;
  final DateTime createdAt;
  final String? photoUrl;     // посилання на фото у Firebase Storage

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.rating,
    this.car,
    required this.createdAt,
    this.photoUrl,
  });

  factory User.fromMap(String id, Map<String, dynamic> map) {
    return User(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      car: map['car'] != null ? Car.fromMap(map['car']) : null,
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      photoUrl: map['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'rating': rating,
      'car': car?.toMap(),
      'createdAt': createdAt,
      'photoUrl': photoUrl,
    };
  }
}