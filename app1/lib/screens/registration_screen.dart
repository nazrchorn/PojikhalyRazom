import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController carBrandController = TextEditingController();
  final TextEditingController carModelController = TextEditingController();
  final TextEditingController carYearController = TextEditingController();
  final TextEditingController carColorController = TextEditingController();
  final TextEditingController carSeatsController = TextEditingController();

  DateTime? selectedBirthDate;
  String selectedGender = "Чоловік";
  bool _isPasswordVisible = false;
  bool _isLoading = false;

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

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    carBrandController.dispose();
    carModelController.dispose();
    carYearController.dispose();
    carColorController.dispose();
    carSeatsController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оберіть дату народження')),
      );
      return;
    }

    final int carYear = int.parse(carYearController.text.trim());
    final int carSeats = int.parse(carSeatsController.text.trim());

    setState(() => _isLoading = true);
    try {
      await _authService.registerUser(
        RegistrationRequest(
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          phone: phoneController.text.trim(),
          password: passwordController.text.trim(),
          gender: selectedGender,
          birthDate: selectedBirthDate!,
          carBrand: carBrandController.text.trim(),
          carModel: carModelController.text.trim(),
          carYear: carYear,
          carColor: carColorController.text.trim(),
          carSeats: carSeats,
        ),
      );

      await NotificationService.instance.refreshToken();

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося зареєструватися')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
          prefixIcon: Icon(icon, color: primaryTurquoise, size: 20),
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
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обов\'язкове поле';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final String? requiredError = _requiredValidator(value);
    if (requiredError != null) {
      return requiredError;
    }
    final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(value!.trim())) {
      return 'Введіть коректний email';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final String? requiredError = _requiredValidator(value);
    if (requiredError != null) {
      return requiredError;
    }
    if (value!.trim().length < 6) {
      return 'Мінімум 6 символів';
    }
    return null;
  }

  String? _yearValidator(String? value) {
    final String? requiredError = _requiredValidator(value);
    if (requiredError != null) {
      return requiredError;
    }
    final int? parsed = int.tryParse(value!.trim());
    final int currentYear = DateTime.now().year;
    if (parsed == null || parsed < 1980 || parsed > currentYear + 1) {
      return 'Некоректний рік';
    }
    return null;
  }

  String? _seatsValidator(String? value) {
    final String? requiredError = _requiredValidator(value);
    if (requiredError != null) {
      return requiredError;
    }
    final int? parsed = int.tryParse(value!.trim());
    if (parsed == null || parsed < 1 || parsed > 8) {
      return 'Вкажіть 1-8 місць';
    }
    return null;
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: primaryTurquoise.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Заповніть дані профілю та авто. Це займає 1-2 хвилини.',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 18),
                _buildSectionCard(
                  title: 'Особиста інформація',
                  children: [
                    _buildTextField(nameController, "Повне ім'я", Icons.person_outline, validator: _requiredValidator),
                    _buildTextField(
                      emailController,
                      'Email',
                      Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                      validator: _emailValidator,
                    ),
                    _buildTextField(
                      phoneController,
                      'Телефон',
                      Icons.phone_android_outlined,
                      keyboardType: TextInputType.phone,
                      validator: _requiredValidator,
                    ),
                    _buildTextField(
                      passwordController,
                      'Пароль',
                      Icons.lock_outline,
                      isPassword: true,
                      validator: _passwordValidator,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: backgroundDeep,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.cake_outlined, color: primaryTurquoise, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedBirthDate == null
                                          ? 'Дата народження'
                                          : '${selectedBirthDate!.day}.${selectedBirthDate!.month}.${selectedBirthDate!.year}',
                                      style: TextStyle(
                                        color: selectedBirthDate == null ? Colors.grey.shade700 : Colors.black87,
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                            decoration: BoxDecoration(
                              color: backgroundDeep,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedGender,
                                isExpanded: true,
                                items: ['Чоловік', 'Жінка'].map((String value) {
                                  return DropdownMenuItem<String>(value: value, child: Text(value));
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
                  ],
                ),
                const SizedBox(height: 18),
                _buildSectionCard(
                  title: 'Перше авто',
                  children: [
                    _buildTextField(
                      carBrandController,
                      'Марка',
                      Icons.directions_car_filled_outlined,
                      validator: _requiredValidator,
                    ),
                    _buildTextField(
                      carModelController,
                      'Модель',
                      Icons.info_outline,
                      validator: _requiredValidator,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            carColorController,
                            'Колір',
                            Icons.palette_outlined,
                            validator: _requiredValidator,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            carYearController,
                            'Рік',
                            Icons.calendar_today,
                            keyboardType: TextInputType.number,
                            validator: _yearValidator,
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      carSeatsController,
                      'Кількість місць',
                      Icons.event_seat_outlined,
                      keyboardType: TextInputType.number,
                      validator: _seatsValidator,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTurquoise,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Створити акаунт',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Вже маєш акаунт? Увійди',
                      style: TextStyle(color: Colors.blueGrey.shade700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}