import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app_user;

class PublicProfileScreen extends StatelessWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  // Твої фірмові кольори
  final Color primaryTurquoise = const Color(0xFF5DD9C1);
  final Color bgTurquoiseLight = const Color(0xFFE8F8F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text("Профіль", style: TextStyle(fontWeight: FontWeight.bold)), // Нейтральна назва
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: primaryTurquoise));
          }

          final user = app_user.User.fromMap(
              snapshot.data!.id,
              snapshot.data!.data() as Map<String, dynamic>
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // --- Аватар та основна інфо ---
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: bgTurquoiseLight,
                        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                        child: user.photoUrl == null
                            ? Icon(Icons.person, size: 60, color: primaryTurquoise)
                            : null,
                      ),
                      const SizedBox(height: 15),
                      Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(
                        "${user.age ?? 'Вік не вказано'} років • ${user.phone}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                          Text(" ${user.rating.toStringAsFixed(1)} ", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("(${user.tripsCompleted} поїздок)", style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- Секція "Про себе" ---
                _buildSectionTitle("Про себе"),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      _buildHabitRow(
                        user.isTalkative ? Icons.chat_rounded : Icons.speaker_notes_off_rounded,
                        user.isTalkative ? "Любить побалакати" : "Мовчазний у дорозі",
                      ),
                      const Divider(height: 24),
                      _buildHabitRow(
                        user.musicType == "speakers" ? Icons.music_note_rounded : Icons.headset_rounded,
                        user.musicType == "speakers" ? "Слухає музику в салоні" : "Тільки в навушниках",
                      ),
                      const Divider(height: 24),
                      _buildHabitRow(
                        user.isSmoker ? Icons.smoking_rooms_rounded : Icons.smoke_free_rounded,
                        user.isSmoker ? "Палить" : "Не палить",
                      ),
                      const Divider(height: 24),
                      _buildHabitRow(
                        user.allowSmoking ? Icons.check_circle_outline : Icons.block_flipped,
                        user.allowSmoking ? "Дозволяє палити в авто" : "Палити в салоні заборонено",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // --- Блок Транспорт (нейтральний колір та назва) ---
                if (user.car != null) ...[
                  _buildSectionTitle("Транспортний засіб"), // Прибрали "водія"
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.shade100),
                    ),
                    color: Colors.white, // Гарантуємо відсутність фіолетового
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: bgTurquoiseLight, // Бірюзовий фон іконки
                            borderRadius: BorderRadius.circular(12)
                        ),
                        child: Icon(Icons.directions_car_filled_rounded, color: primaryTurquoise),
                      ),
                      title: Text("${user.car!.brand} ${user.car!.model}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        "Колір: ${user.car!.color ?? '—'} • Номер: ${user.car!.plateNumber ?? 'Приховано'}",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),
                // Універсальна фраза про відгуки
                const Text(
                    "Відгуки про користувача поки що відсутні",
                    style: TextStyle(color: Colors.grey, fontSize: 14)
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildHabitRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: primaryTurquoise, size: 22),
        const SizedBox(width: 15),
        Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    );
  }
}