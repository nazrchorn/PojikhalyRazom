import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/car.dart';
import '../models/user.dart' as app_user;

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _dismissedReviewPromptsField = 'dismissedReviewPromptTripIds';
  static const String _dismissReviewPromptsForeverField = 'dismissReviewPromptsForever';

  Future<Map<String, dynamic>?> loadUserData(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data();
  }

  Future<app_user.User?> loadUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) {
      return null;
    }
    final data = doc.data();
    if (data == null) {
      return null;
    }
    return app_user.User.fromMap(doc.id, data);
  }

  Future<void> upsertUser(app_user.User user) {
    return _firestore.collection('users').doc(user.id).set(user.toMap());
  }

  Future<void> updatePhotoUrl(String userId, String photoUrl) {
    return _firestore.collection('users').doc(userId).update({'photoUrl': photoUrl});
  }

  Future<Set<String>> loadDismissedReviewPromptTripIds(String userId) async {
    if (userId.trim().isEmpty) return <String>{};
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data() ?? <String, dynamic>{};
    final raw = data[_dismissedReviewPromptsField];
    if (raw is! List) return <String>{};
    return raw.map((item) => item.toString()).where((id) => id.trim().isNotEmpty).toSet();
  }

  Future<void> dismissReviewPromptForever({
    required String userId,
    required String tripId,
  }) async {
    if (userId.trim().isEmpty || tripId.trim().isEmpty) return;
    await _firestore.collection('users').doc(userId).set({
      _dismissedReviewPromptsField: FieldValue.arrayUnion([tripId]),
    }, SetOptions(merge: true));
  }

  Future<bool> loadIsReviewPromptDismissedForever(String userId) async {
    if (userId.trim().isEmpty) return false;
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data() ?? <String, dynamic>{};
    return data[_dismissReviewPromptsForeverField] == true;
  }

  Future<void> dismissAllReviewPromptsForever(String userId) async {
    if (userId.trim().isEmpty) return;
    await _firestore.collection('users').doc(userId).set({
      _dismissReviewPromptsForeverField: true,
    }, SetOptions(merge: true));
  }

   Future<String> uploadProfilePhoto({
     required String userId,
     required File file,
   }) async {
     try {
       if (!file.existsSync()) {
         throw Exception('Файл не знайдено: ${file.path}');
       }
       
       final fileSize = file.lengthSync();
       if (fileSize == 0) {
         throw Exception('Файл порожній');
       }
       
       final ref = _storage.ref().child('profile_photos/$userId/avatar.jpg');
       await ref.putFile(file);
       final downloadUrl = await ref.getDownloadURL();
       return downloadUrl;
     } catch (e) {
       rethrow;
     }
   }

  Future<void> addCar(String userId, Car car) {
    return _firestore.collection('users').doc(userId).update({
      'cars': FieldValue.arrayUnion([car.toMap()]),
    });
  }

  Future<void> deleteCar(String userId, Car car) {
    return _firestore.collection('users').doc(userId).update({
      'cars': FieldValue.arrayRemove([car.toMap()]),
    });
  }

  Future<void> updateUserRating({
    required String userId,
    required int newRating,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    final Map<String, dynamic> userData = userDoc.data() ?? <String, dynamic>{};
    final double currentRating = (userData['rating'] ?? 0).toDouble();
    final int reviewCount = (userData['reviewCount'] ?? 0).toInt();
    final int nextCount = reviewCount + 1;
    final double calculated = (currentRating * reviewCount + newRating) / nextCount;

    await userRef.update({
      'rating': calculated,
      'reviewCount': nextCount,
    });
  }

  int extractMaxCarSeats(Map<String, dynamic> data, {int fallback = 4}) {
    final dynamic cars = data['cars'];
    if (cars is List && cars.isNotEmpty && cars.first is Map<String, dynamic>) {
      final dynamic seats = (cars.first as Map<String, dynamic>)['seats'];
      if (seats is int && seats > 0) {
        return seats;
      }
      if (seats is num && seats > 0) {
        return seats.toInt();
      }
    }

    final dynamic legacyCar = data['car'];
    if (legacyCar is Map<String, dynamic>) {
      final dynamic seats = legacyCar['seats'];
      if (seats is int && seats > 0) {
        return seats;
      }
      if (seats is num && seats > 0) {
        return seats.toInt();
      }
    }

    return fallback;
  }
}

