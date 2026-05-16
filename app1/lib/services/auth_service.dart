import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class RegistrationRequest {
  final String name;
  final String email;
  final String phone;
  final String password;
  final String gender;
  final DateTime birthDate;

  const RegistrationRequest({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.gender,
    required this.birthDate,
  });
}

class AuthService {
  AuthService({
    fb_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? fb_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final fb_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<fb_auth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<String> registerUser(RegistrationRequest request) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: request.email,
      password: request.password,
    );

    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw StateError('Не вдалося створити користувача');
    }

    final userData = <String, dynamic>{
      'name': request.name,
      'email': firebaseUser.email,
      'phone': request.phone,
      'gender': request.gender,
      'birthDate': request.birthDate,
      'createdAt': FieldValue.serverTimestamp(),
      'photoUrl': null,
      'tripsCompleted': 0,
      'rating': 5.0,
      'cars': <Map<String, dynamic>>[],
    };

    await _firestore.collection('users').doc(firebaseUser.uid).set(userData);
    return firebaseUser.uid;
  }
}

