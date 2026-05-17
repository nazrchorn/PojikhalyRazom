import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/notification_service.dart';
import '../theme/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Поїхали Разом',
      applicationVersion: '1.0.0',
      children: const [Text('Сервіс спільних поїздок Україною.')],
    );
  }

  Future<void> _contactSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@pojikhaly-razom.app',
      query: 'subject=Підтримка Поїхали Разом',
    );
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося відкрити поштовий клієнт')),
      );
    }
  }

  Future<void> _contactSupportTelegram() async {
    final opened = await launchUrl(Uri.parse('https://t.me/pojikhaly_razom_support'));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося відкрити Telegram')),
      );
    }
  }

  Future<void> _openNotificationSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вийти з акаунта?'),
        content: const Text('Ви зможете увійти знову в будь-який момент.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Вийти')),
        ],
      ),
    );

    if (confirm != true) return;
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити обліковий запис?'),
        content: const Text(
          'Цю дію не можна скасувати. Дані профілю та доступ до поїздок буде втрачено.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Видалити')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uid = user.uid;
      await user.delete();
      await _firestore.collection('users').doc(uid).delete();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'requires-recent-login'
          ? 'Для видалення акаунта потрібен повторний вхід. Увійдіть заново і спробуйте ще раз.'
          : 'Не вдалося видалити акаунт: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося видалити акаунт: $e')),
      );
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: ListView(
        children: [
          _sectionTitle('Зовнішній вигляд'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (_, mode, __) {
              final isDark = mode == ThemeMode.dark;
              return SwitchListTile.adaptive(
                value: isDark,
                title: const Text('Темна тема'),
                subtitle: const Text('Глибокий темно-бірюзовий стиль інтерфейсу'),
                secondary: const Icon(Icons.dark_mode_rounded),
                onChanged: (v) {
                  if (v) {
                    ThemeController.setDark();
                  } else {
                    ThemeController.setLight();
                  }
                },
              );
            },
          ),
          const Divider(height: 1),

          _sectionTitle('Сповіщення'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Налаштування сповіщень'),
            subtitle: const Text('Усі параметри сповіщень в одному місці'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openNotificationSettings,
          ),
          const Divider(height: 1),

          _sectionTitle('Підтримка'),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Написати на пошту підтримки'),
            subtitle: const Text('support@pojikhaly-razom.app'),
            onTap: _contactSupportEmail,
          ),
          ListTile(
            leading: const Icon(Icons.telegram_rounded),
            title: const Text('Telegram підтримка'),
            subtitle: const Text('@pojikhaly_razom_support'),
            onTap: _contactSupportTelegram,
          ),
          const Divider(height: 1),

          _sectionTitle('Акаунт'),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Вийти з облікового запису'),
            onTap: _signOut,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            title: const Text('Видалити обліковий запис', style: TextStyle(color: Colors.redAccent)),
            subtitle: const Text('Безповоротно видалить профіль і дані'),
            onTap: _deleteAccount,
          ),
          const Divider(height: 1),

          _sectionTitle('Додатково'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Про застосунок'),
            onTap: _showAbout,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;

  bool _pushEnabled = true;
  bool _chatEnabled = true;
  bool _bookingEnabled = true;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? <String, dynamic>{};
      final settings = (data['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final n = (settings['notifications'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _pushEnabled = n['pushEnabled'] != false;
        _chatEnabled = n['chatEnabled'] != false;
        _bookingEnabled = n['bookingEnabled'] != false;
        _soundEnabled = n['soundEnabled'] != false;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await _firestore.collection('users').doc(uid).set({
        'settings': {
          'notifications': {
            'pushEnabled': _pushEnabled,
            'chatEnabled': _chatEnabled,
            'bookingEnabled': _bookingEnabled,
            'soundEnabled': _soundEnabled,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestPermission() async {
    await NotificationService.instance.requestPermissionsAgain();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Запит на дозвіл сповіщень відправлено')),
    );
  }

  Future<void> _openSystemSettings() async {
    final opened = await launchUrl(Uri.parse('app-settings:'));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося відкрити системні налаштування')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сповіщення')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile.adaptive(
                  value: _pushEnabled,
                  title: const Text('Push-сповіщення'),
                  secondary: const Icon(Icons.notifications_active_outlined),
                  onChanged: (v) async {
                    setState(() => _pushEnabled = v);
                    await _save();
                  },
                ),
                SwitchListTile.adaptive(
                  value: _chatEnabled,
                  title: const Text('Сповіщення чату'),
                  secondary: const Icon(Icons.chat_bubble_outline_rounded),
                  onChanged: (v) async {
                    setState(() => _chatEnabled = v);
                    await _save();
                  },
                ),
                SwitchListTile.adaptive(
                  value: _bookingEnabled,
                  title: const Text('Сповіщення бронювань'),
                  secondary: const Icon(Icons.car_rental_outlined),
                  onChanged: (v) async {
                    setState(() => _bookingEnabled = v);
                    await _save();
                  },
                ),
                SwitchListTile.adaptive(
                  value: _soundEnabled,
                  title: const Text('Звук сповіщень'),
                  secondary: const Icon(Icons.volume_up_rounded),
                  onChanged: (v) async {
                    setState(() => _soundEnabled = v);
                    await _save();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.key_rounded),
                  title: const Text('Запросити дозвіл на сповіщення'),
                  onTap: _requestPermission,
                ),
                ListTile(
                  leading: const Icon(Icons.settings_rounded),
                  title: const Text('Системні налаштування сповіщень'),
                  subtitle: const Text('Відкрити налаштування застосунку на телефоні'),
                  onTap: _openSystemSettings,
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
    );
  }
}

