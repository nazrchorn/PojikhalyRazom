# Рекомендації для подальшого розвитку

## Що було зроблено

### ✅ Створені нові сервіси (Service Layer)

1. **MapService** - 131 рядок
   - Управління всіма пошуками адрес через Nominatim
   - Типи форматування для різних екранів
   - Централізована обробка помилок

2. **ChatService** - 91 рядок
   - Управління повідомленнями
   - Операції редагування/видалення
   - Позначення як прочитане
   - Завантаження профілів користувачів

3. **ReviewService** - 80 рядків
   - Управління відгуками
   - Розрахунок рейтингів
   - Перевірка актуальності відгуків

### ✅ Рефакторені екрани

1. **city_search_screen.dart** - видалено 50 рядків API логіки
2. **departure_search_screen.dart** - видалено 30 рядків API логіки
3. **arrival_search_screen.dart** - видалено 30 рядків API логіки
4. **messanger_screen.dart** - видалено 80+ рядків Firestore логіки
5. **reviews_list_screen.dart** - видалено 30 рядків Firestore логіки

---

## Рекомендації щодо подальших покращень

### 1. **Додати кеширування**

```dart
// У MapService додати локальне кешування результатів
class MapService {
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  
  Future<List<Map<String, dynamic>>> searchAddresses(String query) async {
    // Перевірити кеш перед запитом
    if (_cache.containsKey(query)) {
      return _cache[query]!;
    }
    
    // ... виконати запит
    _cache[query] = results;
    return results;
  }
}
```

### 2. **Додати State Management (Provider або Riverpod)**

```dart
// Замість напрямого використання сервісів у екранах:
final chatProvider = StreamProvider<List<Message>>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getMessagesForUser(userId);
});

// Тоді у екрані:
@override
Widget build(BuildContext context, WidgetRef ref) {
  final messages = ref.watch(chatProvider);
  return messages.when(
    data: (data) => ...,
    loading: () => ...,
    error: (err, _) => ...,
  );
}
```

### 3. **Додати DTO (Data Transfer Objects)**

```dart
// Створити моделі для API відповідей
class AddressDto {
  final String city;
  final String address;
  final double lat;
  final double lng;
  
  AddressDto({...});
  
  factory AddressDto.fromNominatim(Map<String, dynamic> json) {
    // parsing logic
  }
}
```

### 4. **Додати Repository Pattern**

```dart
abstract class AddressRepository {
  Future<List<Address>> search(String query);
}

class NominatimAddressRepository implements AddressRepository {
  final MapService _mapService;
  
  @override
  Future<List<Address>> search(String query) async {
    // ... використовувати _mapService
  }
}
```

### 5. **Додати Unit Тести**

```dart
void main() {
  group('MapService', () {
    test('searchAddresses returns list of addresses', () async {
      final service = MapService();
      final result = await service.searchAddresses('Львів');
      expect(result, isNotEmpty);
      expect(result[0], containsPair('city', isNotEmpty));
    });
  });
}
```

### 6. **Додати Logger**

```dart
import 'package:logger/logger.dart';

class MapService {
  final logger = Logger();
  
  Future<List<Map<String, dynamic>>> searchAddresses(String query) async {
    logger.i('Searching addresses for: $query');
    try {
      final results = await ...;
      logger.i('Found ${results.length} addresses');
      return results;
    } catch (e) {
      logger.e('Error searching addresses', error: e);
      rethrow;
    }
  }
}
```

### 7. **Додати Custom Exceptions**

```dart
class MapServiceException implements Exception {
  final String message;
  final String? stackTrace;
  
  MapServiceException({required this.message, this.stackTrace});
  
  @override
  String toString() => message;
}

// Використання:
try {
  // ... запит
} catch (e) {
  throw MapServiceException(
    message: 'Failed to search addresses: $e',
    stackTrace: '$e',
  );
}
```

---

## Як дотримуватися архітектури при додаванні нових функцій

### Сценарій: Додати новий екран для історії поїздок

#### ❌ НЕПРАВИЛЬНО:
```dart
class TripHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: FirebaseFirestore.instance
            .collection('trips')
            .where('userId', isEqualTo: userId)
            .get(), // ← API запит прямо в UI!
        builder: (context, snapshot) { ... }
      ),
    );
  }
}
```

#### ✅ ПРАВИЛЬНО:
```dart
// 1. Додати метод в TripService
class TripService {
  Stream<List<Trip>> getUserTripHistory(String userId) {
    return tripsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('departureTime', descending: true)
        .snapshots()
        .map((snapshot) => ...);
  }
}

// 2. Використати сервіс у екрані
class TripHistoryScreen extends StatelessWidget {
  final TripService _tripService = TripService();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: _tripService.getUserTripHistory(userId),
        builder: (context, snapshot) { ... }
      ),
    );
  }
}
```

---

## Хідліст перевірки для нових екранів

При додаванні нового екрану переконайтеся:

- [ ] Екран **не містить** прямих запитів до Firebase чи API
- [ ] Екран **не містить** import 'package:http/http.dart'
- [ ] Екран **не містить** import 'package:cloud_firestore/cloud_firestore.dart'
- [ ] Уся логіка запитів винесена в окремий сервіс
- [ ] Сервіс розташовується у `lib/services/`
- [ ] Сервіс має **чітку** відповідальність
- [ ] Екран **використовує** сервіс через dependency injection
- [ ] Коментарії пояснюють **що** робить код, а не **як**

---

## Залежності які варто додати

```yaml
dependencies:
  # State management
  provider: ^6.0.0
  # або
  riverpod: ^2.0.0
  
  # Logging
  logger: ^2.0.0
  
  # Testing
  mocktail: ^1.0.0
  
  # API handling
  dio: ^5.0.0  # замість http
  
  # Local caching
  hive: ^2.0.0
  hive_flutter: ^1.0.0
```

---

## Приклад повної структури для нового сервісу

```dart
// lib/services/notification_service_new.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final Logger _logger = Logger();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  // Ініціалізація
  Future<void> initialize() async {
    try {
      _logger.i('Initializing NotificationService');
      // ...
    } catch (e) {
      _logger.e('Failed to initialize notifications', error: e);
      rethrow;
    }
  }
  
  // Основна логіка
  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      _logger.e('Failed to get FCM token', error: e);
      rethrow;
    }
  }
  
  // Stream для слухання повідомлень
  Stream<RemoteMessage> get onMessage {
    return FirebaseMessaging.onMessage;
  }
}
```

---

## Питання при захисті диплома та відповіді

**Питання:** "Чому ви винесли логіку пошуку адрес з екрана?"
**Відповідь:** 
> "Це дотримання принципу Single Responsibility. Екран має лише відображати UI, а не знати деталі про HTTP запити до Nominatim. Окрім того, це дає нам:
> - Можливість легко замінити Nominatim на Google Maps
> - Можливість переиспользовувати сервіс в інших екранах
> - Легші unit тести для логіки пошуку"

**Питання:** "Як це впливає на тестування?"
**Відповідь:**
> "Тепер я можу легко нами чмок MapService для unit тестів, без необхідності мокувати цілий Firebase чи HTTP запити:"

```dart
class MockMapService extends MapService {
  @override
  Future<List<Map<String, dynamic>>> searchAddresses(String query) async {
    return [
      {'city': 'Стародобський', 'address': 'вул. Центральна', ...}
    ];
  }
}
```

---

## Контактна інформація для подальших покращень

При виявленні проблем з архітектурою:
1. Перевірити, чи логіка винесена в сервіс
2. Перевірити, чи екран використовує сервіс
3. Додати обробку помилок в сервіс
4. Додати логування для діагностики

Успіхів у розвитку проекту! 🚀

