import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─── Top-level background handler (must be top-level function) ───────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised before this runs.
  // Background / terminated notifications are shown automatically by FCM on
  // Android, so no extra work is needed here for now.
}

// ─── Service ─────────────────────────────────────────────────────────────────
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;

  static const _channelId = 'chat_messages';
  static const _channelName = 'Повiдомлення чату';
  static const _channelDesc = 'Нові повiдомлення вiд iнших користувачiв';

  final _localNotifications = FlutterLocalNotificationsPlugin();
  void Function(Map<String, dynamic>)? _onNotificationTap;

  // Call once from main() after Firebase.initializeApp()
  Future<void> initialize({
    void Function(Map<String, dynamic>)? onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap;
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Set up Android notification channel
    await _createAndroidChannel();

    // Init flutter_local_notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            _emitNotificationTap(decoded);
          }
        } catch (_) {
          // Ignore malformed payloads to avoid breaking notification flow.
        }
      },
    );

    // Request permission (Android 13+, iOS)
    await _requestPermission();

    // Save FCM token to Firestore when user is logged in
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
    final token = await _fcm.getToken();
    if (token != null) await _saveTokenToFirestore(token);

    // Handle foreground messages – show local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _emitNotificationTap(Map<String, dynamic>.from(message.data));
    });

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        _emitNotificationTap(Map<String, dynamic>.from(initialMessage.data));
      });
    }

    // iOS: show foreground notifications as banners
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // Re-save token after login (call from auth flow if needed)
  Future<void> refreshToken() async {
    final token = await _fcm.getToken();
    if (token != null) await _saveTokenToFirestore(token);
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      final plugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  Future<void> _createAndroidChannel() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final payloadData = Map<String, dynamic>.from(message.data);

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(payloadData),
    );
  }

  void _emitNotificationTap(Map<String, dynamic> data) {
    _onNotificationTap?.call(data);
  }
}

