# Архітектурний Рефакторинг - Дизайн-документація

## Проблеми, які були вирішені

### 1. **Порушення принципу Single Responsibility (SRP)**

#### Проблема:
- Екрани пошуку адрес (`city_search_screen.dart`, `departure_search_screen.dart`, `arrival_search_screen.dart`) містили прямі HTTP-запити й обробку API
- Екрани месенджера та відгуків містили прямі запити до Firestore
- UI-логіка була змішана з бізнес-логікою і логікою доступу до даних

#### Розв'язання:
Розділили на **3 шари архітектури**:
```
┌─────────────────────────────────────────────┐
│          UI LAYER (Screens)                 │  ← Тільки відображення
│  - city_search_screen.dart                  │
│  - messanger_screen.dart                    │
│  - reviews_list_screen.dart                 │
└────────────────────┬────────────────────────┘
                     │ використовує
                     ▼
┌─────────────────────────────────────────────┐
│       SERVICE LAYER (Business Logic)        │  ← Обробка логіки
│  - MapService                               │
│  - ChatService                              │
│  - ReviewService                            │
│  - TripService (був)                        │
└────────────────────┬────────────────────────┘
                     │ обращається до
                     ▼
┌─────────────────────────────────────────────┐
│      DATA LAYER (API & Database)            │  ← Доступ до даних
│  - Firebase Firestore                       │
│  - OpenStreetMap Nominatim API              │
└─────────────────────────────────────────────┘
```

---

## Нові сервіси

### 1. **MapService** (`lib/services/map_service.dart`)

**Відповідальність:** Управління географічними запитами й пошуком адрес

**Методи:**
- `searchAddresses(query)` - універсальний пошук адрес
- `searchAddressesForDeparture(query)` - пошук з форматуванням для DepartureSearchScreen
- `searchAddressesForArrival(query)` - пошук з форматуванням для ArrivalSearchScreen

**Переваги:**
```dart
// РАНІШЕ (у экранах):
final response = await http.get(Uri.parse(url), headers: {...});
if (response.statusCode == 200) {
  final data = json.decode(utf8.decode(response.bodyBytes));
  // ... обробка 20+ рядків коду
}

// ТЕПЕР (у экранах):
final suggestions = await MapService().searchAddresses(query);
```

**Централізація:**
- Усі API-ключи й заголовки User-Agent в одному місці
- Єдина обробка помилок
- Легше змінювати API провайдера (Nominatim → Google Maps → Yandex)

---

### 2. **ChatService** (`lib/services/chat_service.dart`)

**Відповідальність:** Управління всіма операціями з чатами й повідомленнями

**Методи:**
- `getMessagesForUser(uid)` - поток всіх повідомлень користувача
- `getConversationMessages(currentUserId, partnerId)` - поток розмови
- `sendMessage()` - відправка повідомлення
- `editMessage()` - редагування повідомлення
- `deleteMessage()` - видалення повідомлення
- `markIncomingAsRead()` - позначення як прочитане
- `loadUserSummary()` - завантаження профілю користувача

**Раніше в MessangerScreen:**
```dart
Stream<QuerySnapshot> _messagesForUser(String uid) {
  return FirebaseFirestore.instance
      .collection('messages')
      .where(Filter.or(...))
      .snapshots();
}

// ... ще 5-6 методів з логікою Firestore
```

**Тепер:**
```dart
final ChatService _chatService = ChatService();

// А потім просто:
_chatService.getMessagesForUser(authUser.uid)
```

---

### 3. **ReviewService** (`lib/services/review_service.dart`)

**Відповідальність:** Управління всіма операціями з відгуками

**Методи:**
- `getReviewsForUser(userId)` - поток відгуків для користувача
- `loadReviewsForUser(userId)` - Future для одного завантаження
- `addReview()` - додавання новго відгуку
- `getAverageRating(userId)` - розрахунок середної оцінки
- `getReviewsForTrip()` - отримати відгуки за поїздкою
- `hasUserReviewedTrip()` - перевірка, чи вже залишив відгук

---

## Рефакторені екрани

### 1. **CitySearchScreen**
```dart
// РАНІШЕ: 218 рядків, 50+ рядків Nominatim API логіки
// ТЕПЕР: 218 рядків, API логіка винесена в MapService

// Видалено:
- import 'dart:convert'
- import 'package:http/http.dart' as http
- _apiKey константа
- 50 рядків в _fetchSuggestions()

// Додано:
- import '../services/map_service.dart'
- final MapService _mapService = MapService()
- 3 рядки коду замість 50
```

### 2. **DepartureSearchScreen & ArrivalSearchScreen**
Аналогічні зміни як у CitySearchScreen

### 3. **MessangerScreen & ConversationScreen**
```dart
// РАНІШЕ:
- FirebaseFirestore запити прямо в build()
- 7 допоміжних методів (_messagesForUser, _loadUserSummary...)
- 50+ рядків управління Firestore операціями

// ТЕПЕР:
- final ChatService _chatService = ChatService()
- Чистий, читаний код з делегуванням на сервіс
```

### 4. **ReviewsListScreen**
```dart
// РАНІШЕ:
FirebaseFirestore.instance
    .collection('reviews')
    .where('toUserId', isEqualTo: userId)
    .orderBy('createdAt', descending: true)
    .snapshots()

// ТЕПЕР:
ReviewService().getReviewsForUser(userId)
```

---

## Переваги архітектури

### ✅ **Розділення відповідальності**
- Екран = тільки **UI/UX логіка**
- Сервіс = **бізнес-логіка**
- API/DB = **доступ до даних**

### ✅ **Легше тестувати**
```dart
// Можна замімікувати ChatService для unit тестів
class MockChatService extends ChatService {
  @override
  Future<void> sendMessage(...) async {
    // mock implementation
  }
}
```

### ✅ **Легше змінювати провайдерів**
```dart
// Якщо замінити Nominatim на Google Maps:
// Змінювати лише MapService, не екрани!

class MapService {
  Future<List<Map<String, dynamic>>> searchAddresses(String query) async {
    // Замінити на Google Maps API
    final response = await _googleMapsApi.search(query);
    // ... виходить той самий формат
  }
}
```

### ✅ **Легше масштабувати**
- Додати новий екран пошуку? Просто викликай `MapService().searchAddresses()`
- Додати нові операції з чатом? Просто додай метод в `ChatService`

### ✅ **Покращена читаність коду**
- Екран показує **що** відбувається (UI)
- Сервіс показує **як** це робиться (логіка)

### ✅ **Централізована обробка помилок**
```dart
// Раніше: обробка помилок в кожному екрані
// Тепер: один блок try-catch в сервісі
```

---

## Приклади використання

### Використання MapService
```dart
final mapService = MapService();

try {
  final addresses = await mapService.searchAddressesForDeparture('Львів');
  setState(() {
    suggestions = addresses;
  });
} catch (e) {
  setState(() {
    errorMessage = 'Помилка підключення';
  });
}
```

### Використання ChatService
```dart
final chatService = ChatService();

// Отримати все повідомлення користувача
final messagesStream = chatService.getMessagesForUser(authUser.uid);

// Відправити повідомлення
await chatService.sendMessage(
  currentUserId: currentUserId,
  receiverId: partnerId,
  text: messageText,
);

// Позначити як прочитане
await chatService.markIncomingAsRead(docs, currentUserId);
```

### Використання ReviewService
```dart
final reviewService = ReviewService();

// Отримати відгуки
final reviewsStream = reviewService.getReviewsForUser(userId);

// Розрахувати рейтинг
final avgRating = await reviewService.getAverageRating(userId);

// Додати новий відгук
await reviewService.addReview(newReview);
```

---

## Структура файлів після рефакторингу

```
lib/
├── services/
│   ├── map_service.dart           ✅ НОВИЙ
│   ├── chat_service.dart          ✅ НОВИЙ
│   ├── review_service.dart        ✅ НОВИЙ
│   ├── trip_service.dart          (вже існував)
│   ├── car_data_service.dart      (вже існував)
│   └── notification_service.dart  (вже існував)
├── screens/
│   ├── city_search_screen.dart    ✏️ РЕФАКТОРЕНО
│   ├── departure_search_screen.dart ✏️ РЕФАКТОРЕНО
│   ├── arrival_search_screen.dart ✏️ РЕФАКТОРЕНО
│   ├── messanger_screen.dart      ✏️ РЕФАКТОРЕНО
│   ├── reviews_list_screen.dart   ✏️ РЕФАКТОРЕНО
│   └── ... інші екрани
└── ...
```

---

## Висновок для захисту диплома

При демонстрації коду професорові можна сказати:

> "Я дотримався **Clean Architecture** принципів і розділив код на три шари:
> 1. **UI Layer** (Screens) - тільки відображення
> 2. **Service Layer** (Services) - бізнес-логіка й гро операції
> 3. **Data Layer** (Firebase, API) - доступ до зовнішніх ресурсів
>
> Це дає нам:
> - ✅ Чистіший і більш читаємий код
> - ✅ Легше тестувати
> - ✅ Легше змінювати API провайдерів
> - ✅ Легше масштабувати функціональність
> - ✅ Дотримання принципу Single Responsibility"

Такий підхід вказує на **професійний рівень архітектури** й буде отримати позитивні оцінки при захисті!

