import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

// ─────────────────────────────────────────────────────────────
// Registration Form Validator (бізнес-логіка валідації)
// ─────────────────────────────────────────────────────────────
class RegistrationFormValidator {
  static String? validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обов\'язкове поле';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final required = validateRequired(value);
    if (required != null) return required;

    final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(value!.trim())) {
      return 'Введіть коректний email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final required = validateRequired(value);
    if (required != null) return required;

    if (value!.trim().length < 6) {
      return 'Мінімум 6 символів';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    final required = validateRequired(value);
    if (required != null) return required;

    final cleanedPhone = value!.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanedPhone.length < 9) {
      return 'Введіть коректний номер';
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────
// Registration Screen (UI-фокусний, чистий)
// ─────────────────────────────────────────────────────────────
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  // ── Theme Colors ──────────────────────────────────────────
  static const Color _primaryTurquoise = Color(0xFF1F6F66);
  static const Color _backgroundDeep = Color(0xFFF3F8F7);
  static const Color _accentTurquoiseSoft = Color(0xFFDDF5F1);
  static const Color _accentTurquoiseSurface = Color(0xFFF2FBF8);
  static const Color _errorRed = Color(0xFFD32F2F);
  static const Color _successGreen = Color(0xFF388E3C);

  // ── Form Keys & Controllers ──────────────────────────────
  final GlobalKey<FormState> _formKey1 = GlobalKey<FormState>();
  final GlobalKey<FormState> _formKey2 = GlobalKey<FormState>();
  final GlobalKey<FormState> _formKey3 = GlobalKey<FormState>();

  final AuthService _authService = AuthService();

  // ── Form Data ────────────────────────────────────────────
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // ── UI State ────────────────────────────────────────────
  int _currentStep = 0;
  DateTime? selectedBirthDate;
  String selectedGender = "Чоловік";
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ── Step Navigation ──────────────────────────────────────
  void _nextStep() {
    setState(() => _errorMessage = null);

    if (_currentStep == 0) {
      if (_formKey1.currentState!.validate()) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (_formKey2.currentState!.validate()) {
        if (selectedBirthDate == null) {
          setState(() => _errorMessage = 'Оберіть дату народження');
          return;
        }
        setState(() => _currentStep = 2);
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickerScheme = Theme.of(context).colorScheme.copyWith(
      primary: _primaryTurquoise,
      secondary: _primaryTurquoise,
    );
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: pickerScheme,
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: _primaryTurquoise,
              headerForegroundColor: Colors.white,
              todayBorder: const BorderSide(color: _primaryTurquoise),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => selectedBirthDate = picked);
    }
  }

  // ── Registration Logic ───────────────────────────────────
  Future<void> _register() async {
    if (!_formKey3.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    _errorMessage = null;

    try {
      await _authService.registerUser(
        RegistrationRequest(
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          phone: phoneController.text.trim(),
          password: passwordController.text.trim(),
          gender: selectedGender,
          birthDate: selectedBirthDate!,
        ),
      );

      await NotificationService.instance.refreshToken();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Помилка реєстрації: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── UI Components ───────────────────────────────────────
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword && !_isPasswordVisible,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accentTurquoiseSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primaryTurquoise, size: 18),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  onPressed: () {
                    setState(() => _isPasswordVisible = !_isPasswordVisible);
                  },
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _accentTurquoiseSoft),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _primaryTurquoise, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (index) {
            final isCompleted = index < _currentStep;
            final isCurrent = index == _currentStep;
            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted || isCurrent
                          ? _primaryTurquoise
                          : Colors.grey.shade300,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent ? Colors.white : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ['Облік', 'Особисто', 'Підтвердити'][index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent ? _primaryTurquoise : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: (_currentStep + 1) / 3,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(_primaryTurquoise),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _errorRed.withValues(alpha: 0.1),
        border: Border.all(color: _errorRed.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _errorRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: _errorRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step Content Builders ────────────────────────────────
  Widget _buildStep1Credentials() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Облік для входу',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _primaryTurquoise,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ці дані потрібні для входу в програму',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              emailController,
              'Email',
              Icons.alternate_email,
              keyboardType: TextInputType.emailAddress,
              validator: RegistrationFormValidator.validateEmail,
            ),
            _buildTextField(
              passwordController,
              'Пароль (мін. 6 символів)',
              Icons.lock_outline,
              isPassword: true,
              validator: RegistrationFormValidator.validatePassword,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2PersonalInfo() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Особиста інформація',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _primaryTurquoise,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Допоможіть нам дізнатися вас краще',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              nameController,
              "Повне ім'я",
              Icons.person_outline,
              validator: RegistrationFormValidator.validateRequired,
            ),
            _buildTextField(
              phoneController,
              'Телефон',
              Icons.phone_android_outlined,
              keyboardType: TextInputType.phone,
              validator: RegistrationFormValidator.validatePhone,
            ),
            if (_errorMessage != null) ...[
              _buildErrorMessage(),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                      decoration: BoxDecoration(
                        color: _accentTurquoiseSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _accentTurquoiseSoft),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cake_outlined, color: _primaryTurquoise, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedBirthDate == null
                                  ? 'Дата народження'
                                  : '${selectedBirthDate!.day}.${selectedBirthDate!.month}.${selectedBirthDate!.year}',
                              style: TextStyle(
                                color: selectedBirthDate == null
                                    ? Colors.grey.shade700
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _accentTurquoiseSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _accentTurquoiseSoft),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGender,
                        isExpanded: true,
                        items: ['Чоловік', 'Жінка'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() => selectedGender = value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3Review() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Перевірка даних',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _primaryTurquoise,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Переконайтесь, що все заповнено правильно',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            _buildReviewCard('Email', emailController.text),
            _buildReviewCard('Ім\'я', nameController.text),
            _buildReviewCard('Телефон', phoneController.text),
            _buildReviewCard('Стать', selectedGender),
            _buildReviewCard(
              'Дата народження',
              selectedBirthDate != null
                  ? '${selectedBirthDate!.day}.${selectedBirthDate!.month}.${selectedBirthDate!.year}'
                  : 'Не обрано',
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              _buildErrorMessage(),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accentTurquoiseSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentTurquoiseSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundDeep,
      appBar: AppBar(
        title: const Text("Реєстрація", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Theme.of(context).appBarTheme.surfaceTintColor,
        elevation: 0,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        automaticallyImplyLeading: _currentStep == 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress Bar ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildProgressBar(),
            ),

            // ── Step Content ──────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: IndexedStack(
                  index: _currentStep,
                  children: [
                    _buildStep1Credentials(),
                    _buildStep2PersonalInfo(),
                    _buildStep3Review(),
                  ],
                ),
              ),
            ),

            // ── Navigation Buttons ────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _previousStep,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Назад'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : (_currentStep < 2 ? _nextStep : _register),
                      icon: _isLoading
                          ? const SizedBox.shrink()
                          : Icon(
                              _currentStep < 2
                                  ? Icons.arrow_forward
                                  : Icons.check,
                            ),
                      label: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _currentStep < 2
                                  ? 'Далі'
                                  : 'Створити акаунт',
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryTurquoise,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Back to Login Link ────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Уже маєш акаунт? Увійди',
                  style: TextStyle(color: Colors.blueGrey.shade700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}