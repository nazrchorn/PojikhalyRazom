import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import 'avatar_crop_screen.dart';
import '../services/user_service.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late DateTime? _birthDate;

  late bool _isTalkative;
  late bool _isSmoker;
  late bool _allowSmoking;
  late String _musicType;

  File? _selectedImage;
  final UserService _userService = UserService();
  final Color primaryTurquoise = const Color(0xFF1F6F66);
  final Color bgTurquoiseLight = const Color(0xFFE8F8F5);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _emailController = TextEditingController(text: widget.user.email);
    _birthDate = widget.user.birthDate;
    _isTalkative = widget.user.isTalkative;
    _isSmoker = widget.user.isSmoker;
    _allowSmoking = widget.user.allowSmoking;
    _musicType = widget.user.musicType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

   Future<void> _pickImage() async {
     try {
       final picker = ImagePicker();
       final navigator = Navigator.of(context);
       final pickedFile = await picker.pickImage(
         source: ImageSource.gallery,
         imageQuality: 85,
         maxWidth: 2048,
         maxHeight: 2048,
         requestFullMetadata: false,
       );
       if (pickedFile == null || !mounted) return;

       final croppedFile = await navigator.push<File?>(
         MaterialPageRoute(
           builder: (_) => AvatarCropScreen(imageFile: File(pickedFile.path), accentColor: primaryTurquoise),
         ),
       );

       if (croppedFile == null) {
         if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Кадрування скасовано')),
         );
         return;
       }

       if (!mounted) return;
       setState(() => _selectedImage = croppedFile);

       if (croppedFile.lengthSync() > 5 * 1024 * 1024) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Файл занадто великий (максимум 5MB)')),
         );
         return;
       }
     } catch (e) {
       debugPrint('Помилка при виборі фото: $e');
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Помилка при виборі фото: ${e.toString()}')),
       );
     }
   }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Редагувати профіль", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Theme.of(context).appBarTheme.surfaceTintColor,
        elevation: 0,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Аватар
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: bgTurquoiseLight,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (widget.user.photoUrl != null ? NetworkImage(widget.user.photoUrl!) : null) as ImageProvider?,
                      child: (_selectedImage == null && widget.user.photoUrl == null)
                          ? Icon(Icons.person, size: 60, color: primaryTurquoise) : null,
                    ),
                    Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 18, backgroundColor: primaryTurquoise, child: const Icon(Icons.camera_alt, size: 18, color: Colors.white))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            _buildLabel("ОСНОВНІ ДАНІ"),
            _buildCustomTextField("Ім'я", _nameController, Icons.person_outline_rounded),
            _buildCustomTextField("Пошта", _emailController, Icons.email_outlined),
            _buildCustomTextField("Телефон", _phoneController, Icons.phone_android_rounded),
            _buildDatePickerField(),

            const SizedBox(height: 25),
            _buildLabel("АТМОСФЕРА В ДОРОЗІ"),
            _buildSettingsCard([
              _buildEditSwitch("Люблю поговорити", Icons.forum_rounded, _isTalkative, (v) => setState(() => _isTalkative = v)),
              const Divider(height: 1),
              _buildEditSwitch("Я палю", Icons.smoking_rooms_rounded, _isSmoker, (v) => setState(() => _isSmoker = v)),
              const Divider(height: 1),
              _buildEditSwitch("Можна палити в салоні", Icons.smoke_free_rounded, _allowSmoking, (v) => setState(() => _allowSmoking = v)),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(_musicType == "music" ? Icons.music_note_rounded : Icons.volume_off_rounded, color: primaryTurquoise),
                    const SizedBox(width: 15),
                    const Text("Музика", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: "silence", icon: Icon(Icons.volume_off, size: 20)),
                        ButtonSegment(value: "music", icon: Icon(Icons.music_note, size: 20)),
                      ],
                      selected: {_musicType},
                      onSelectionChanged: (val) => setState(() => _musicType = val.first),
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: primaryTurquoise,
                        selectedForegroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTurquoise,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: const Text("Зберегти зміни", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 10, bottom: 8),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
  );

  Widget _buildCustomTextField(String label, TextEditingController controller, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryTurquoise),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDatePickerField() {
    final dateText = _birthDate != null
        ? '${_birthDate!.day}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.year}'
        : 'Не вказано';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: ListTile(
        leading: Icon(Icons.calendar_today_rounded, color: primaryTurquoise),
        title: const Text('День народження'),
        subtitle: Text(dateText, style: TextStyle(color: Colors.grey.shade600)),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: _birthDate ?? DateTime(now.year - 25, 1, 1),
            firstDate: DateTime(1950),
            lastDate: now,
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
            setState(() => _birthDate = picked);
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        tileColor: Colors.white,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildEditSwitch(String title, IconData icon, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      secondary: Icon(icon, color: primaryTurquoise),
      value: value,
      activeThumbColor: primaryTurquoise,
      onChanged: onChanged,
    );
  }

  Future<void> _saveChanges() async {
    String? photoUrl = widget.user.photoUrl;

    if (_selectedImage != null) {
      photoUrl = await _userService.uploadProfilePhoto(
        userId: widget.user.id,
        file: _selectedImage!,
      );
    }

    final updatedUser = User(
      id: widget.user.id,
      name: _nameController.text,
      email: _emailController.text.isNotEmpty ? _emailController.text : widget.user.email,
      phone: _phoneController.text,
      rating: widget.user.rating,
      cars: widget.user.cars,
      createdAt: widget.user.createdAt,
      photoUrl: photoUrl,
      gender: widget.user.gender,
      birthDate: _birthDate,
      isTalkative: _isTalkative,
      musicType: _musicType,
      isSmoker: _isSmoker,
      allowSmoking: _allowSmoking,
      tripsCompleted: widget.user.tripsCompleted,
    );

    await _userService.upsertUser(updatedUser);
    if (!mounted) {
      return;
    }
    Navigator.pop(context, updatedUser);
  }
}