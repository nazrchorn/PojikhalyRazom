import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  // Контролери основних полів
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Контролери для машини
  final TextEditingController carBrandController = TextEditingController();
  final TextEditingController carModelController = TextEditingController();
  final TextEditingController carYearController = TextEditingController();
  final TextEditingController carColorController = TextEditingController(); // Нове поле
  final TextEditingController carSeatsController = TextEditingController();

  DateTime? selectedBirthDate;
  String selectedGender = "Чоловік";

  final Color primaryTurquoise = const Color(0xFF5DD9C1);
  final Color backgroundDeep = const Color(0xFFF2F5F8);

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryTurquoise),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => selectedBirthDate = picked);
    }
  }

  Future<void> _register() async {
    if (selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Оберіть дату народження")));
      return;
    }

    try {
      final credential = await fbAuth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final firebaseUser = credential.user;

      Map<String, dynamic> userData = {
        "name": nameController.text.trim(),
        "email": firebaseUser!.email,
        "phone": phoneController.text.trim(),
        "gender": selectedGender,
        "birthDate": selectedBirthDate,
        "createdAt": FieldValue.serverTimestamp(),
        "photoUrl": null,
        "tripsCompleted": 0,
        "rating": 5.0,
        "cars": [
          {
            "brand": carBrandController.text.trim(),
            "model": carModelController.text.trim(),
            "year": int.tryParse(carYearController.text.trim()),
            "color": carColorController.text.trim(), // Зберігаємо колір
            "seats": int.tryParse(carSeatsController.text.trim()),
          }
        ]
      };

      await FirebaseFirestore.instance.collection("users").doc(firebaseUser.uid).set(userData);

      Navigator.pop(context, userData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Не вдалося зареєструватися")));
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryTurquoise, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDeep,
      appBar: AppBar(
        title: const Text("Реєстрація", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Особиста інформація", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildTextField(nameController, "Повне ім'я", Icons.person_outline),
            _buildTextField(emailController, "Email", Icons.alternate_email),
            _buildTextField(phoneController, "Телефон", Icons.phone_android_outlined),
            _buildTextField(passwordController, "Пароль", Icons.lock_outline, isPassword: true),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                      child: Row(
                        children: [
                          Icon(Icons.cake_outlined, color: primaryTurquoise, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            selectedBirthDate == null
                                ? "ДН"
                                : "${selectedBirthDate!.day}.${selectedBirthDate!.month}.${selectedBirthDate!.year}",
                            style: TextStyle(color: selectedBirthDate == null ? Colors.grey : Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGender,
                        isExpanded: true,
                        items: ["Чоловік", "Жінка"].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (val) => setState(() => selectedGender = val!),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            const Text("Ваше авто", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Column(
                children: [
                  _buildTextField(carBrandController, "Марка", Icons.directions_car_filled_outlined),
                  _buildTextField(carModelController, "Модель", Icons.info_outline),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(carColorController, "Колір", Icons.palette_outlined)), // Колір
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(carYearController, "Рік", Icons.calendar_today)),
                    ],
                  ),
                  _buildTextField(carSeatsController, "Кількість місць", Icons.event_seat_outlined),
                ],
              ),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTurquoise,
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: const Text("Зареєструватися", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}