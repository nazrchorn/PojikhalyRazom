import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_request.dart';
import 'chat_service.dart';

class BookingService {
  BookingService({
    FirebaseFirestore? firestore,
    ChatService? chatService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _chatService = chatService ?? ChatService();

  final FirebaseFirestore _firestore;
  final ChatService _chatService;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('booking_requests');

  Future<void> _sendSystemMessageSafe({
    required String receiverId,
    required String text,
    required String tripId,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _chatService.sendSystemMessage(
        receiverId: receiverId,
        text: text,
        tripId: tripId,
        type: type,
        metadata: metadata,
      );
    } catch (_) {
      // Fallback for projects where message rules allow only a fixed field set.
      if (metadata != null && metadata.isNotEmpty) {
        try {
          await _chatService.sendSystemMessage(
            receiverId: receiverId,
            text: text,
            tripId: tripId,
            type: type,
          );
        } catch (_) {
          // Keep booking flow successful even if notification fails.
        }
      }
    }
  }

  Stream<List<BookingRequest>> watchTripPendingRequests(String tripId) {
    return _requests
        .where('tripId', isEqualTo: tripId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingRequest.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<BookingRequest>> watchDriverPendingRequests(String driverId) {
    return _requests
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingRequest.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<BookingRequest?> watchRequestById(String requestId) {
    return _requests.doc(requestId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return BookingRequest.fromMap(doc.id, doc.data()!);
    });
  }

  Future<BookingRequest?> getRequestById(String requestId) async {
    final doc = await _requests.doc(requestId).get();
    if (!doc.exists || doc.data() == null) return null;
    return BookingRequest.fromMap(doc.id, doc.data()!);
  }

  Stream<BookingRequest?> watchPassengerLatestRequest(String tripId, String passengerId) {
    return _requests
        .where('tripId', isEqualTo: tripId)
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return BookingRequest.fromMap(doc.id, doc.data());
        });
  }

  Future<void> createBookingRequest({
    required String tripId,
    required String driverId,
    required String passengerId,
    required String passengerName,
    String? fromCity,
    String? toCity,
    double? requestedPrice,
    double? pickupLat,
    double? pickupLng,
    String? pickupAddress,
    double? dropoffLat,
    double? dropoffLng,
    String? dropoffAddress,
  }) async {
    final activeStatuses = ['pending', 'confirmed'];
    final existing = await _requests
        .where('tripId', isEqualTo: tripId)
        .where('passengerId', isEqualTo: passengerId)
        .where('status', whereIn: activeStatuses)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw StateError('Запит вже iснує або бронювання вже пiдтверджено');
    }

    final doc = _requests.doc();
    await doc.set({
      'tripId': tripId,
      'driverId': driverId,
      'passengerId': passengerId,
      'fromCity': fromCity,
      'toCity': toCity,
      'status': 'pending',
      'requestedPrice': requestedPrice,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'pickupAddress': pickupAddress,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'dropoffAddress': dropoffAddress,
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
      'respondedBy': null,
    });

    await Future.wait([
      _sendSystemMessageSafe(
        receiverId: driverId,
        text: 'Новий запит на бронювання в поїздці. Відкрийте, щоб переглянути та підтвердити.',
        tripId: tripId,
        type: 'booking_request_created',
        metadata: {
          'bookingRequestId': doc.id,
          'passengerId': passengerId,
          'fromCity': fromCity,
          'toCity': toCity,
        },
      ),
      _sendSystemMessageSafe(
        receiverId: passengerId,
        text: 'Ваш запит на бронювання надiслано водiю. Очiкуйте пiдтвердження.',
        tripId: tripId,
        type: 'booking_request_created_passenger',
        metadata: {
          'fromCity': fromCity,
          'toCity': toCity,
        },
      ),
    ]);
  }

  Future<void> updateRequestStopPointByDriver({
    required String requestId,
    required bool isPickup,
    required double lat,
    required double lng,
    required String address,
  }) async {
    final requestRef = _requests.doc(requestId);
    final snap = await requestRef.get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Запит не знайдено');
    }

    final data = snap.data()!;
    if ((data['status'] as String? ?? '') != 'pending') {
      throw StateError('Змінювати можна лише активний запит');
    }

    final tripId = data['tripId'] as String? ?? '';
    final passengerId = data['passengerId'] as String? ?? '';
    final fieldPrefix = isPickup ? 'pickup' : 'dropoff';

    await requestRef.update({
      '${fieldPrefix}Lat': lat,
      '${fieldPrefix}Lng': lng,
      '${fieldPrefix}Address': address,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByDriverAt': FieldValue.serverTimestamp(),
    });

    final pointLabel = isPickup ? 'посадки' : 'висадки';
    await _sendSystemMessageSafe(
      receiverId: passengerId,
      text: 'Водій оновив точку $pointLabel у вашому запиті. Перегляньте зміни перед підтвердженням.',
      tripId: tripId,
      type: isPickup ? 'booking_request_pickup_updated' : 'booking_request_dropoff_updated',
      metadata: {
        'bookingRequestId': requestId,
        'address': address,
        'isPickup': isPickup,
      },
    );
  }

  Future<void> acknowledgeRequestUpdateByPassenger({
    required String requestId,
    required String passengerName,
  }) async {
    final requestRef = _requests.doc(requestId);
    final requestSnap = await requestRef.get();
    if (!requestSnap.exists || requestSnap.data() == null) {
      throw StateError('Запит не знайдено');
    }

    final data = requestSnap.data()!;
    if ((data['status'] as String? ?? '') != 'pending') {
      throw StateError('Запит вже оброблено');
    }

    final tripId = data['tripId'] as String? ?? '';
    final driverId = data['driverId'] as String? ?? '';

    await requestRef.update({
      'passengerAcknowledgedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _sendSystemMessageSafe(
      receiverId: driverId,
      text: '$passengerName погодив(ла) оновлену точку в запиті на бронювання.',
      tripId: tripId,
      type: 'booking_request_update_acknowledged',
      metadata: {
        'bookingRequestId': requestId,
      },
    );
  }

  Future<void> confirmBookingRequest({
    required String requestId,
    required String driverName,
  }) async {
    final requestRef = _requests.doc(requestId);
    late Map<String, dynamic> requestData;

    await _firestore.runTransaction((tx) async {
      final reqSnap = await tx.get(requestRef);
      if (!reqSnap.exists) {
        throw StateError('Запит не знайдено');
      }

      requestData = reqSnap.data()!;
      if (requestData['status'] != 'pending') {
        throw StateError('Запит вже оброблено');
      }

      final tripId = requestData['tripId'] as String? ?? '';
      final passengerId = requestData['passengerId'] as String? ?? '';
      final fromCity = requestData['fromCity'] as String?;
      final toCity = requestData['toCity'] as String?;
      final requestedPrice = (requestData['requestedPrice'] as num?)?.toDouble();

      final tripRef = _firestore.collection('trips').doc(tripId);
      final tripSnap = await tx.get(tripRef);
      if (!tripSnap.exists) {
        throw StateError('Поїздку не знайдено');
      }

      final trip = tripSnap.data() ?? <String, dynamic>{};
      final seats = (trip['availableSeats'] as num?)?.toInt() ?? 0;
      final passengers = List<String>.from(trip['passengers'] ?? const <String>[]);

      if (passengers.contains(passengerId) || seats <= 0) {
        throw StateError('Немає доступних мiсць для пiдтвердження');
      }

      tx.update(tripRef, {
        'availableSeats': seats - 1,
        'passengers': FieldValue.arrayUnion([passengerId]),
        if (fromCity != null && fromCity.isNotEmpty)
          'passengerSegments.$passengerId.fromCity': fromCity,
        if (toCity != null && toCity.isNotEmpty)
          'passengerSegments.$passengerId.toCity': toCity,
        if (requestedPrice != null)
          'passengerSegments.$passengerId.requestedPrice': requestedPrice,
      });

      tx.update(requestRef, {
        'status': 'confirmed',
        'respondedAt': FieldValue.serverTimestamp(),
        'respondedBy': requestData['driverId'],
      });
    });

    final tripId = requestData['tripId'] as String? ?? '';
    final passengerId = requestData['passengerId'] as String? ?? '';
    final driverId = requestData['driverId'] as String? ?? '';

    await Future.wait([
      _chatService.sendSystemMessage(
        receiverId: passengerId,
        text: '$driverName пiдтвердив ваш запит на бронювання. Гарної поїздки!',
        tripId: tripId,
        type: 'booking_request_confirmed',
      ),
      _chatService.sendSystemMessage(
        receiverId: driverId,
        text: 'Ви пiдтвердили запит пасажира. Мiсце заброньовано.',
        tripId: tripId,
        type: 'booking_request_confirmed',
      ),
    ]);
  }

  Future<void> rejectBookingRequest({
    required String requestId,
    required String driverName,
  }) async {
    final requestRef = _requests.doc(requestId);
    final requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw StateError('Запит не знайдено');
    }

    final data = requestSnap.data()!;
    if (data['status'] != 'pending') {
      throw StateError('Запит вже оброблено');
    }

    await requestRef.update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
      'respondedBy': data['driverId'],
    });

    final tripId = data['tripId'] as String? ?? '';
    final passengerId = data['passengerId'] as String? ?? '';
    final driverId = data['driverId'] as String? ?? '';

    await Future.wait([
      _chatService.sendSystemMessage(
        receiverId: passengerId,
        text: '$driverName вiдхилив запит на бронювання.',
        tripId: tripId,
        type: 'booking_request_rejected',
      ),
      _chatService.sendSystemMessage(
        receiverId: driverId,
        text: 'Ви вiдхилили запит на бронювання.',
        tripId: tripId,
        type: 'booking_request_rejected',
      ),
    ]);
  }

  Future<void> cancelLatestByPassenger({
    required String tripId,
    required String passengerId,
  }) async {
    final snapshot = await _requests
        .where('tripId', isEqualTo: tripId)
        .where('passengerId', isEqualTo: passengerId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw StateError('Активного запиту не знайдено');
    }

    final doc = snapshot.docs.first;
    final data = doc.data();
    final String status = data['status'] as String? ?? '';
    final String driverId = data['driverId'] as String? ?? '';

    await _firestore.runTransaction((tx) async {
      final reqRef = _requests.doc(doc.id);
      final freshReq = await tx.get(reqRef);
      if (!freshReq.exists) {
        throw StateError('Запит не знайдено');
      }

      final reqData = freshReq.data()!;
      final reqStatus = reqData['status'] as String? ?? '';
      if (reqStatus != 'pending' && reqStatus != 'confirmed') {
        throw StateError('Запит вже неактивний');
      }

      if (reqStatus == 'confirmed') {
        final tripRef = _firestore.collection('trips').doc(tripId);
        final tripSnap = await tx.get(tripRef);
        final tripData = tripSnap.data() ?? <String, dynamic>{};
        final seats = (tripData['availableSeats'] as num?)?.toInt() ?? 0;
        final passengers = List<String>.from(tripData['passengers'] ?? const <String>[]);
        if (passengers.contains(passengerId)) {
          passengers.remove(passengerId);
          tx.update(tripRef, {
            'availableSeats': seats + 1,
            'passengers': passengers,
            'passengerSegments.$passengerId': FieldValue.delete(),
          });
        }
      }

      tx.update(reqRef, {
        'status': 'cancelled',
        'respondedAt': FieldValue.serverTimestamp(),
        'respondedBy': passengerId,
      });
    });

    final actionText = status == 'confirmed'
        ? 'скасував(ла) бронювання в поїздцi.'
        : 'скасував(ла) запит на бронювання.';

    await Future.wait([
      _chatService.sendSystemMessage(
        receiverId: driverId,
        text: 'Пасажир $actionText',
        tripId: tripId,
        type: 'booking_request_cancelled',
      ),
      _chatService.sendSystemMessage(
        receiverId: passengerId,
        text: 'Ваш запит/бронювання скасовано.',
        tripId: tripId,
        type: 'booking_request_cancelled',
      ),
    ]);
  }

  Future<void> cancelRequestByPassenger({
    required String requestId,
    required String passengerId,
  }) async {
    final requestRef = _requests.doc(requestId);
    final requestSnap = await requestRef.get();
    if (!requestSnap.exists || requestSnap.data() == null) {
      throw StateError('Запит не знайдено');
    }

    final data = requestSnap.data()!;
    if ((data['passengerId'] as String? ?? '') != passengerId) {
      throw StateError('Скасувати може лише пасажир цього запиту');
    }

    final tripId = data['tripId'] as String? ?? '';
    final status = data['status'] as String? ?? '';
    final driverId = data['driverId'] as String? ?? '';

    await _firestore.runTransaction((tx) async {
      final freshReq = await tx.get(requestRef);
      if (!freshReq.exists || freshReq.data() == null) {
        throw StateError('Запит не знайдено');
      }

      final reqData = freshReq.data()!;
      final reqStatus = reqData['status'] as String? ?? '';
      if (reqStatus != 'pending' && reqStatus != 'confirmed') {
        throw StateError('Запит вже неактивний');
      }

      if (reqStatus == 'confirmed') {
        final tripRef = _firestore.collection('trips').doc(tripId);
        final tripSnap = await tx.get(tripRef);
        final tripData = tripSnap.data() ?? <String, dynamic>{};
        final seats = (tripData['availableSeats'] as num?)?.toInt() ?? 0;
        final passengers = List<String>.from(tripData['passengers'] ?? const <String>[]);
        if (passengers.contains(passengerId)) {
          passengers.remove(passengerId);
          tx.update(tripRef, {
            'availableSeats': seats + 1,
            'passengers': passengers,
            'passengerSegments.$passengerId': FieldValue.delete(),
          });
        }
      }

      tx.update(requestRef, {
        'status': 'cancelled',
        'respondedAt': FieldValue.serverTimestamp(),
        'respondedBy': passengerId,
      });
    });

    final actionText = status == 'confirmed'
        ? 'скасував(ла) бронювання в поїздцi.'
        : 'скасував(ла) запит на бронювання.';

    await Future.wait([
      _chatService.sendSystemMessage(
        receiverId: driverId,
        text: 'Пасажир $actionText',
        tripId: tripId,
        type: 'booking_request_cancelled',
      ),
      _chatService.sendSystemMessage(
        receiverId: passengerId,
        text: 'Ваш запит/бронювання скасовано.',
        tripId: tripId,
        type: 'booking_request_cancelled',
      ),
    ]);
  }
}

