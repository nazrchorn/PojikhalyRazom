# 📚 Практичний гайд: Як використовувати новий Service Layer

## 🎯 Швидкий старт

### 1. MapService - Пошук адрес

#### Сценарій: Додати пошук адреси в новий екран

```dart
import 'package:flutter/material.dart';
import '../services/map_service.dart';

class MyNewSearchScreen extends StatefulWidget {
  @override
  State<MyNewSearchScreen> createState() => _MyNewSearchScreenState();
}

class _MyNewSearchScreenState extends State<MyNewSearchScreen> {
  final MapService _mapService = MapService();
  List<Map<String, dynamic>> results = [];
  bool isLoading = false;

  Future<void> handleSearch(String query) async {
    setState(() => isLoading = true);
    
    try {
      final addresses = await _mapService.searchAddresses(query);
      setState(() {
        results = addresses;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка пошуку: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            onChanged: handleSearch,
            decoration: InputDecoration(
              hintText: 'Пошук адреси...',
              suffixIcon: isLoading ? CircularProgressIndicator() : null,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return ListTile(
                  title: Text(result['properties']['locality'] ?? 'Unknown'),
                  subtitle: Text(result['properties']['label'] ?? ''),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

#### Доступні методи MapService:

```dart
// Універсальний пошук
final results = await mapService.searchAddresses('Київ');

// Для екрана відправлення
final departureResults = await mapService.searchAddressesForDeparture('вул. Хрещатик');

// Для екрана прибуття
final arrivalResults = await mapService.searchAddressesForArrival('Львів');
```

---

### 2. ChatService - Управління чатами

#### Сценарій: Показати список чатів користувача

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatListScreen extends StatelessWidget {
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      return Center(child: Text('Увійдіть в систему'));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Чати')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chatService.getMessagesForUser(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Чатів немає'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final message = snapshot.data!.docs[index];
              return ListTile(
                title: Text(message['text']),
                subtitle: Text(message['senderId']),
              );
            },
          );
        },
      ),
    );
  }
}
```

#### Сценарій: Відправити повідомлення

```dart
class ChatScreen extends StatefulWidget {
  final String partnerId;
  final String currentUserId;

  const ChatScreen({
    required this.partnerId,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      await _chatService.sendMessage(
        currentUserId: widget.currentUserId,
        receiverId: widget.partnerId,
        text: text,
      );
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка відправки: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _chatService.getConversationMessages(
                widget.currentUserId,
                widget.partnerId,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return ListTile(
                      title: Text(msg['text']),
                      subtitle: Text(msg['sentAt'].toString()),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(hintText: 'Коментар...'),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### Доступні методи ChatService:

```dart
// 📨 Отримати потік повідомлень користувача
_chatService.getMessagesForUser(userId)

// 💬 Отримати потік розмови з конкретною особою
_chatService.getConversationMessages(currentUserId, partnerId)

// ✉️ Відправити повідомлення
await _chatService.sendMessage(
  currentUserId: 'user123',
  receiverId: 'user456',
  text: 'Привіт!',
);

// ✏️ Редагувати повідомлення
await _chatService.editMessage('docId', 'Новий текст');

// 🗑️ Видалити повідомлення
await _chatService.deleteMessage('docId');

// ☑️ Позначити як прочитане
await _chatService.markIncomingAsRead(docs, currentUserId);

// 👤 Завантажити профіль користувача
final userInfo = await _chatService.loadUserSummary('userId');
```

---

### 3. ReviewService - Управління відгуками

#### Сценарій: Показати список відгуків користувача

```dart
import '../services/review_service.dart';
import '../models/review.dart';

class UserReviewsScreen extends StatelessWidget {
  final String userId;
  final ReviewService _reviewService = ReviewService();

  UserReviewsScreen({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Відгуки')),
      body: StreamBuilder(
        stream: _reviewService.getReviewsForUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Відгуків немає'));
          }

          final reviews = snapshot.data!.docs
              .map((doc) => Review.fromMap(doc.data(), doc.id))
              .toList();

          return ListView.builder(
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              return Card(
                child: ListTile(
                  title: Text('⭐ ' + '★' * review.rating),
                  subtitle: Text(review.comment),
                  trailing: Text(review.role ?? ''),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

#### Сценарій: Показати рейтинг користувача

```dart
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ReviewService _reviewService = ReviewService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<double>(
        future: _reviewService.getAverageRating(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final rating = snapshot.data ?? 0.0;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Рейтинг: ${rating.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text('⭐' * rating.toInt()),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

#### Доступні методи ReviewService:

```dart
// 📋 Отримати потік всіх відгуків користувача
_reviewService.getReviewsForUser(userId)

// 📚 Завантажити список відгуків (Future)
final reviews = await _reviewService.loadReviewsForUser(userId);

// ➕ Додати новий відгук
await _reviewService.addReview(review);

// ⭐ Отримати середню оцінку
final avgRating = await _reviewService.getAverageRating(userId);

// 🚗 Отримати відгуки за поїздкою
_reviewService.getReviewsForTrip(tripId)

// ✓ Перевірити, чи вже залишив відгук
final hasReviewed = await _reviewService.hasUserReviewedTrip(userId, tripId);
```

---

## 🔄 Потоки даних

### MapService Flow
```
User Input → TextField
     ↓
_searchAddress(query)
     ↓
MapService.searchAddresses(query)
     ↓
HTTP GET to Nominatim API
     ↓
Parse JSON & Format
     ↓
Return List<Map>
     ↓
setState() → UI Update
```

### ChatService Flow
```
User Action → Button Click
     ↓
_sendMessage()
     ↓
ChatService.sendMessage()
     ↓
FirebaseFirestore.add()
     ↓
Stream<QuerySnapshot> Update
     ↓
StreamBuilder rebuild
     ↓
UI Shows New Message
```

### ReviewService Flow
```
Load Screen
     ↓
StreamBuilder listens
     ↓
ReviewService.getReviewsForUser(userId)
     ↓
Firestore stream: collection('reviews')
     ↓
Filter & Order by createdAt
     ↓
Emit QuerySnapshot
     ↓
UI Renders Reviews
```

---

## 🚨 Обробка помилок

```dart
// ✅ ПРАВИЛЬНО
try {
  final results = await mapService.searchAddresses(query);
  setState(() => suggestions = results);
} catch (e) {
  setState(() => errorMessage = 'Помилка: $e');
  debugPrint('Full error: $e');
}

// ❌ НЕПРАВИЛЬНО
// final results = await mapService.searchAddresses(query);
// setState(() => suggestions = results); // Crash if error!
```

---

## 💡 Best Practices

### ✅ DO:
- ✅ Використовуйте сервіси з `try-catch` блоками
- ✅ Показуйте loading state під час операцій
- ✅ Логуйте помилки за допомогою debugPrint
- ✅ Очищуйте ресурси при dispose()

### ❌ DON'T:
- ❌ Не викликайте Firestore напрямо з екранів
- ❌ Не робіть HTTP запити без сервісу
- ❌ Не використовуйте сервіси глобальні - създайте нові екземпляри
- ❌ Не забувайте про обробку помилок

---

## 📝 Шаблон для нового сервісу

Якщо вам потрібно створити новий сервіс:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MyNewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Stream методи для реактивних операцій
  Stream<QuerySnapshot> getData() {
    return _firestore.collection('my_collection').snapshots();
  }
  
  // Future методи для одноразових операцій
  Future<void> addData(Map<String, dynamic> data) async {
    try {
      await _firestore.collection('my_collection').add(data);
    } catch (e) {
      rethrow;
    }
  }
  
  // Обробка помилок
  Future<Map<String, dynamic>?> getDataWithErrorHandling(String id) async {
    try {
      final doc = await _firestore.collection('my_collection').doc(id).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error in MyNewService: $e');
      rethrow;
    }
  }
}
```

---

## 🎓 Питання при коді-ревю

**Q:** "Чому ви не кешуєте результати?"
**A:** "Це наступна фаза. MapService можна розширити з кешем."

**Q:** "Як ви обробляєте помилки мережі?"
**A:** "Че-catch блоку в екранах, плюс timeout у MapService."

**Q:** "Чи можна тестувати ці сервіси?"
**A:** "Так! Замімікую Firebase/HTTP для unit тестів."

---

## 🚀 Готово до використання!

Всі сервіси готові до практичного використання.
Якщо виникають питання - див. документацію або надіслати питання!

**Happy Coding! 💻**

