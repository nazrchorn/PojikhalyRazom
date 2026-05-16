import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  final AuthService _authService = AuthService();

  // Твоя фірмова палітра
  final Color primaryTurquoise = const Color(0xFF2F8F7F);
  final Color backgroundDeep = const Color(0xFFF6FCFA);

  Future<void> _handleLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Заповніть всі поля")),
      );
      return;
    }

    try {
      await _authService.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await NotificationService.instance.refreshToken();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Невірний email або пароль")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDeep,
      appBar: AppBar(
        title: const Text("Вхід", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFF4FBF9),
        surfaceTintColor: const Color(0xFFF4FBF9),
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Center( // Центруємо вміст для кращого вигляду
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Логотип
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryTurquoise.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_car_rounded, size: 60, color: primaryTurquoise),
              ),
              const SizedBox(height: 15),
              const Text(
                "Поїхали Разом",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 40),

              // Поле Email
              _buildTextField(
                controller: emailController,
                label: "Email",
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),

              // Поле Пароль
              _buildTextField(
                controller: passwordController,
                label: "Пароль",
                icon: Icons.lock_outline,
                isPassword: true,
                toggleVisibility: () {
                  setState(() => _isPasswordVisible = !_isPasswordVisible);
                },
                isPasswordVisible: _isPasswordVisible,
              ),

              const SizedBox(height: 30),

              // Кнопка входу
              ElevatedButton(
                onPressed: _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTurquoise,
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: const Text(
                  "Увійти",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),

              const SizedBox(height: 20),

              // Кнопка переходу (можна додати навігацію на реєстрацію)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                  );
                },
                child: Text(
                  "Ще немає акаунту? Створи",
                  style: TextStyle(color: Colors.blueGrey.shade600, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Допоміжний метод для створення однакових текстових полів
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    VoidCallback? toggleVisibility,
    bool isPasswordVisible = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isPasswordVisible,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryTurquoise),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
            ),
            onPressed: toggleVisibility,
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }
}