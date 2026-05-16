import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';



void practiceRun()async {
  final user = User(
    id: "user123",
    name: "Іван",
    email: "ivan@example.com",
    phone: "+38050134567",
    rating: 4.8,
    createdAt: DateTime.now(),
  );

  await FirebaseFirestore.instance
      .collection("users")
      .doc(user.id)
      .set(user.toMap());
  final doc = await FirebaseFirestore.instance
      .collection("users")
      .doc(user.id)
      .get();

  debugPrint("Отримано з Firestore: ${doc.data()}");

}

class Car {
   String brand;
   String model;
   int year;
   int seats;

  Car({
    required this.brand,
    required this.model,
    required this.year,
    required this.seats,
  });

  factory Car.fromMap(Map<String, dynamic> map) {
    return Car(
      brand: map['brand'],
      model: map['model'],
      year: map['year'],
      seats: map['seats'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'brand': brand,
      'model': model,
      'year': year,
      'seats': seats,
    };
  }
}
class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final double rating;
  final Car? car;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.rating,
    this.car,
    required this.createdAt,
  });

  factory User.fromMap(String id, Map<String, dynamic> map) {
    return User(
      id: id,
      name: map['name'],
      email: map['email'],
      phone: map['phone'],
      rating: (map['rating'] as num).toDouble(),
      car: map['car'] != null ? Car.fromMap(map['car']) : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
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
    };
  }
}

class Location {
  final String city;
  final double lat;
  final double lng;

  Location({required this.city, required this.lat, required this.lng});

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      city: map['city'],
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'city': city,
      'lat': lat,
      'lng': lng,
    };
  }
}

class Trip {
  final String id;
  final String driverId;
  final Location origin;
  final Location destination;
  final DateTime departureTime;
  final int availableSeats;
  final double pricePerSeat;
  final List<String> passengers;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.driverId,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.availableSeats,
    required this.pricePerSeat,
    required this.passengers,
    required this.createdAt,
  });

  factory Trip.fromMap(String id, Map<String, dynamic> map) {
    return Trip(
      id: id,
      driverId: map['driverId'],
      origin: Location.fromMap(map['origin']),
      destination: Location.fromMap(map['destination']),
      departureTime: (map['departureTime'] as Timestamp).toDate(),
      availableSeats: map['availableSeats'],
      pricePerSeat: (map['pricePerSeat'] as num).toDouble(),
      passengers: List<String>.from(map['passengers']),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'origin': origin.toMap(),
      'destination': destination.toMap(),
      'departureTime': departureTime,
      'availableSeats': availableSeats,
      'pricePerSeat': pricePerSeat,
      'passengers': passengers,
      'createdAt': createdAt,
    };
  }
}

class Booking {
  final String id;
  final String tripId;
  final String passengerId;
  final int seatsBooked;
  final String status; // pending, confirmed, cancelled
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.tripId,
    required this.passengerId,
    required this.seatsBooked,
    required this.status,
    required this.createdAt,
  });

  factory Booking.fromMap(String id, Map<String, dynamic> map) {
    return Booking(
      id: id,
      tripId: map['tripId'],
      passengerId: map['passengerId'],
      seatsBooked: map['seatsBooked'],
      status: map['status'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'passengerId': passengerId,
      'seatsBooked': seatsBooked,
      'status': status,
      'createdAt': createdAt,
    };
  }
}

class Message {
  final String id;
  final String tripId;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime sentAt;

  Message({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.sentAt,
  });

  factory Message.fromMap(String id, Map<String, dynamic> map) {
    return Message(
      id: id,
      tripId: map['tripId'],
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      text: map['text'],
      sentAt: (map['sentAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'sentAt': sentAt,
    };
  }
}

class Rating {
  final String id;
  final String tripId;
  final String reviewerId;
  final String reviewedUserId;
  final int score;
  final String comment;
  final DateTime createdAt;

  Rating({
    required this.id,
    required this.tripId,
    required this.reviewerId,
    required this.reviewedUserId,
    required this.score,
    required this.comment,
    required this.createdAt,
  });

  factory Rating.fromMap(String id, Map<String, dynamic> map) {
    return Rating(
      id: id,
      tripId: map['tripId'],
      reviewerId: map['reviewerId'],
      reviewedUserId: map['reviewedUserId'],
      score: map['score'],
      comment: map['comment'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'reviewerId': reviewerId,
      'reviewedUserId': reviewedUserId,
      'score': score,
      'comment': comment,
      'createdAt': createdAt,
    };
  }
}



class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _carBrandController = TextEditingController();
  final TextEditingController _carModelController = TextEditingController();
  final TextEditingController _carYearController = TextEditingController();
  final TextEditingController _carSeatsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Реєстрація")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Ім'я")),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Телефон")),
            const SizedBox(height: 20),
            const Text("Інформація про авто", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _carBrandController, decoration: const InputDecoration(labelText: "Марка")),
            TextField(controller: _carModelController, decoration: const InputDecoration(labelText: "Модель")),
            TextField(controller: _carYearController, decoration: const InputDecoration(labelText: "Рік"), keyboardType: TextInputType.number),
            TextField(controller: _carSeatsController, decoration: const InputDecoration(labelText: "Кількість місць"), keyboardType: TextInputType.number),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                final car = Car(
                  brand: _carBrandController.text,
                  model: _carModelController.text,
                  year: int.tryParse(_carYearController.text) ?? 0,
                  seats: int.tryParse(_carSeatsController.text) ?? 0,
                );

                final user = User(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: _nameController.text,
                  email: _emailController.text,
                  phone: _phoneController.text,
                  rating: 0.0, // початковий рейтинг, буде змінюватися відгуками
                  car: car,
                  createdAt: DateTime.now(),
                );

                FirebaseFirestore.instance.collection("users").doc(user.id).set(user.toMap());

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Користувач зареєстрований ✅")),
                );

                Navigator.pop(context);
              },
              child: const Text("Зареєструватися"),
            ),
          ],
        ),
      ),
    );
  }
}