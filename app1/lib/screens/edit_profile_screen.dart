import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  late bool _isTalkative;
  late bool _isSmoker;
  late bool _allowSmoking;
  late String _musicType;

  File? _selectedImage;
  final Color primaryTurquoise = const Color(0xFF5DD9C1);
  final Color bgTurquoiseLight = const Color(0xFFE8F8F5);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _isTalkative = widget.user.isTalkative;
    _isSmoker = widget.user.isSmoker;
    _allowSmoking = widget.user.allowSmoking;
    _musicType = widget.user.musicType;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) setState(() => _selectedImage = File(pickedFile.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text("Редагувати профіль", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
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
            _buildCustomTextField("Телефон", _phoneController, Icons.phone_android_rounded),

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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
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

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildEditSwitch(String title, IconData icon, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      secondary: Icon(icon, color: primaryTurquoise),
      value: value,
      activeColor: primaryTurquoise,
      onChanged: onChanged,
    );
  }

  Future<void> _saveChanges() async {
    String? photoUrl = widget.user.photoUrl;

    if (_selectedImage != null) {
      final ref = FirebaseStorage.instance.ref().child("profile_photos/${widget.user.id}.jpg");
      await ref.putFile(_selectedImage!);
      photoUrl = await ref.getDownloadURL();
    }

    final updatedUser = User(
      id: widget.user.id,
      name: _nameController.text,
      email: widget.user.email,
      phone: _phoneController.text,
      rating: widget.user.rating,
      cars: widget.user.cars,
      createdAt: widget.user.createdAt,
      photoUrl: photoUrl,
      gender: widget.user.gender,
      birthDate: widget.user.birthDate,
      isTalkative: _isTalkative,
      musicType: _musicType,
      isSmoker: _isSmoker,
      allowSmoking: _allowSmoking,
      tripsCompleted: widget.user.tripsCompleted,
    );

    await FirebaseFirestore.instance.collection("users").doc(updatedUser.id).set(updatedUser.toMap());
    Navigator.pop(context, updatedUser);
  }
}