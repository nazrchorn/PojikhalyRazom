import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/trip.dart';
import '../services/chat_service.dart';
import '../services/trip_service.dart';
import 'driver_booking_request_screen.dart';
import 'public_profile_screen.dart';
import 'trip_details_screen.dart';

class MessangerScreen extends StatefulWidget {
  const MessangerScreen({super.key});

  @override
  State<MessangerScreen> createState() => _MessangerScreenState();
}

class _MessangerScreenState extends State<MessangerScreen> {
  final Color primaryTurquoise = const Color(0xFF1F6F66);
  final Color systemGreen = const Color(0xFF2E7D32);
  final ChatService _chatService = ChatService();

  Map<String, dynamic> _safeData(DocumentSnapshot<Map<String, dynamic>> doc) {
    return doc.data() ?? <String, dynamic>{};
  }

  DateTime _safeSentAt(Map<String, dynamic> data) {
    final sentAt = data['sentAt'];
    if (sentAt is Timestamp) return sentAt.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _safeText(Map<String, dynamic> data) {
    final text = data['text'];
    if (text is String) return text;
    return '';
  }

  String _safeId(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String) return value;
    return '';
  }

  bool _safeIsRead(Map<String, dynamic> data) {
    final value = data['isRead'];
    return value is bool ? value : false;
  }

  String _formatTime(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '--:--';
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Спочатку увiйдiть у систему')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Чати', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Theme.of(context).appBarTheme.surfaceTintColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chatService.getMessagesForUser(authUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('Ще немає чатiв. Напишiть перше повiдомлення.'),
            );
          }

          final Map<String, _ConversationPreview> previewsByUser = {};
          for (final doc in docs) {
            final data = _safeData(doc);
            final senderId = _safeId(data, 'senderId');
            final receiverId = _safeId(data, 'receiverId');
            final partnerId = senderId == authUser.uid ? receiverId : senderId;

            if (partnerId.isEmpty || partnerId == authUser.uid) {
              continue;
            }

            final candidate = _ConversationPreview(
              partnerId: partnerId,
              lastText: _safeText(data),
              sentAt: _safeSentAt(data),
              unreadCount: receiverId == authUser.uid && !_safeIsRead(data) ? 1 : 0,
            );

            final existing = previewsByUser[partnerId];
            if (existing == null || candidate.sentAt.isAfter(existing.sentAt)) {
              previewsByUser[partnerId] = candidate.copyWith(
                unreadCount: (existing?.unreadCount ?? 0) + candidate.unreadCount,
              );
            } else {
              previewsByUser[partnerId] = existing.copyWith(
                unreadCount: existing.unreadCount + candidate.unreadCount,
              );
            }
          }

          final previews = previewsByUser.values.toList()
            ..sort((a, b) {
              final aSystem = a.partnerId == ChatService.systemChatUserId;
              final bSystem = b.partnerId == ChatService.systemChatUserId;
              if (aSystem && !bSystem) return -1;
              if (!aSystem && bSystem) return 1;
              return b.sentAt.compareTo(a.sentAt);
            });

          if (previews.isEmpty) {
            return const Center(
              child: Text('Ще немає чатiв. Напишiть перше повiдомлення.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: previews.length,
            itemBuilder: (context, index) {
              final preview = previews[index];

              return FutureBuilder<Map<String, dynamic>?>(
                future: _chatService.loadUserSummary(preview.partnerId),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data ?? const <String, dynamic>{};
                  final bool isSystemChat = preview.partnerId == ChatService.systemChatUserId;
                  final userName = (userData['name'] as String?)?.trim();
                  final displayName = (userName == null || userName.isEmpty)
                      ? (isSystemChat ? ChatService.systemChatName : 'Користувач')
                      : userName;
                  final photoUrl = userData['photoUrl'] as String?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isSystemChat
                            ? systemGreen.withValues(alpha: 0.15)
                            : primaryTurquoise.withValues(alpha: 0.15),
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Icon(
                                isSystemChat ? Icons.notifications_active_rounded : Icons.person,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                      title: Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        preview.lastText.isEmpty ? 'Порожнє повiдомлення' : preview.lastText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(preview.sentAt),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          if (preview.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryTurquoise,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                preview.unreadCount > 99 ? '99+' : '${preview.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          else
                            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              currentUserId: authUser.uid,
                              partnerId: preview.partnerId,
                              partnerName: displayName,
                              partnerPhotoUrl: photoUrl,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationPreview {
  final String partnerId;
  final String lastText;
  final DateTime sentAt;
  final int unreadCount;

  _ConversationPreview({
    required this.partnerId,
    required this.lastText,
    required this.sentAt,
    required this.unreadCount,
  });

  _ConversationPreview copyWith({
    String? partnerId,
    String? lastText,
    DateTime? sentAt,
    int? unreadCount,
  }) {
    return _ConversationPreview(
      partnerId: partnerId ?? this.partnerId,
      lastText: lastText ?? this.lastText,
      sentAt: sentAt ?? this.sentAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class ConversationScreen extends StatefulWidget {
  final String currentUserId;
  final String partnerId;
  final String partnerName;
  final String? partnerPhotoUrl;

  const ConversationScreen({
    super.key,
    required this.currentUserId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerPhotoUrl,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final TripService _tripService = TripService();
  final ImagePicker _picker = ImagePicker();

  // Non-null when user is editing an existing message
  String? _editingDocId;
  bool _sendingImage = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _conversationStream() {
    return _chatService.getConversationMessages(
      widget.currentUserId,
      widget.partnerId,
    );
  }

  DateTime _safeSentAt(Map<String, dynamic> data) {
    final sentAt = data['sentAt'];
    if (sentAt is Timestamp) return sentAt.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _safeIsRead(Map<String, dynamic> data) {
    final value = data['isRead'];
    return value is bool ? value : false;
  }

  String _safeTripId(Map<String, dynamic> data) {
    final value = data['tripId'];
    return value is String ? value : '';
  }

  String _safeType(Map<String, dynamic> data) {
    final value = data['type'];
    return value is String ? value : '';
  }

  String _safeImageUrl(Map<String, dynamic> data) {
    final value = data['imageUrl'];
    return value is String ? value : '';
  }

  Map<String, dynamic> _safeMetadata(Map<String, dynamic> data) {
    final value = data['metadata'];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  Map<String, String> _safeReactions(Map<String, dynamic> data) {
    final value = data['reactions'];
    if (value is Map<String, dynamic>) {
      return value.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    }
    if (value is Map) {
      return Map<String, String>.fromEntries(
        value.entries.map((e) => MapEntry(e.key.toString(), e.value?.toString() ?? '')),
      );
    }
    return const <String, String>{};
  }

  Map<String, int> _summarizeReactions(Map<String, String> reactions) {
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      if (emoji.trim().isEmpty) continue;
      counts.update(emoji, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  String _formatTime(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '--:--';
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatTripBadgeText(Trip trip) {
    final dd = trip.departureTime.day.toString().padLeft(2, '0');
    final mm = trip.departureTime.month.toString().padLeft(2, '0');
    final hh = trip.departureTime.hour.toString().padLeft(2, '0');
    final min = trip.departureTime.minute.toString().padLeft(2, '0');
    return '${trip.origin.city} -> ${trip.destination.city} | $dd.$mm $hh:$min';
  }

  Future<void> _markIncomingAsRead(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    await _chatService.markIncomingAsRead(docs, widget.currentUserId);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    if (_editingDocId != null) {
      // Save edit
      final docId = _editingDocId!;
      setState(() => _editingDocId = null);
      await _chatService.editMessage(docId, text);
      return;
    }

    await _chatService.sendMessage(
      currentUserId: widget.currentUserId,
      receiverId: widget.partnerId,
      text: text,
    );

    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pickAndSendImage() async {
    if (_sendingImage) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2200,
      maxHeight: 2200,
    );
    if (picked == null) return;

    final caption = _messageController.text.trim();
    _messageController.clear();

    if (!mounted) return;
    setState(() => _sendingImage = true);
    try {
      await _chatService.sendImageMessage(
        currentUserId: widget.currentUserId,
        receiverId: widget.partnerId,
        imageFile: File(picked.path),
        text: caption,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося відправити фото: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingImage = false);
      }
    }
  }

  void _startEdit(String docId, String currentText) {
    setState(() => _editingDocId = docId);
    _messageController.text = currentText;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: currentText.length),
    );
  }

  void _cancelEdit() {
    setState(() => _editingDocId = null);
    _messageController.clear();
  }

  Future<void> _deleteMessage(BuildContext ctx, String docId) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Видалити повiдомлення?'),
        content: const Text('Це повiдомлення буде видалено назавжди.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Видалити', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _chatService.deleteMessage(docId);
    }
  }

  Future<void> _openTripFromMessage(String tripId) async {
    if (tripId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для цього повiдомлення не вказано поїздку')),
      );
      return;
    }

    final trip = await _tripService.getTripById(tripId);
    if (!mounted) return;

    if (trip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Поїздку не знайдено або її вже видалено')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
    );
  }

  Future<void> _openBookingRequestFromMessage(String requestId) async {
    if (requestId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID запиту не знайдено')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverBookingRequestScreen(requestId: requestId),
      ),
    );
  }

  Future<void> _openPartnerProfile() async {
    if (widget.partnerId == ChatService.systemChatUserId) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: widget.partnerId,
          isMyProfile: widget.currentUserId == widget.partnerId,
        ),
      ),
    );
  }

  Future<void> _showReactionPicker({
    required BuildContext context,
    required String docId,
    required String currentReaction,
  }) async {
    const reactions = <String>['', '❤️', '', '', '', ''];
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final emoji in reactions)
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    if (currentReaction == emoji) {
                      await _chatService.clearMessageReaction(
                        docId: docId,
                        userId: widget.currentUserId,
                      );
                    } else {
                      await _chatService.setMessageReaction(
                        docId: docId,
                        userId: widget.currentUserId,
                        emoji: emoji,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: currentReaction == emoji
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  void _showMessageOptions(
    BuildContext ctx,
    String docId,
    String text,
  ) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Редагувати'),
              onTap: () {
                Navigator.pop(ctx);
                _startEdit(docId, text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Видалити', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMessage(ctx, docId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSystemChat = widget.partnerId == ChatService.systemChatUserId;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Theme.of(context).appBarTheme.surfaceTintColor,
        titleSpacing: 0,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isSystemChat ? null : _openPartnerProfile,
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isSystemChat ? Color(0xFF2E7D32).withValues(alpha: 0.15) : null,
                backgroundImage: (widget.partnerPhotoUrl != null && widget.partnerPhotoUrl!.isNotEmpty)
                    ? NetworkImage(widget.partnerPhotoUrl!)
                    : null,
                child: (widget.partnerPhotoUrl == null || widget.partnerPhotoUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.partnerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (!isSystemChat)
                      Text(
                        'Переглянути профіль',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _conversationStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = (snapshot.data?.docs ?? const [])
                  ..sort((a, b) {
                    final aDate = _safeSentAt(a.data());
                    final bDate = _safeSentAt(b.data());
                    return bDate.compareTo(aDate);
                  });

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Почнiть розмову першим повiдомленням'),
                  );
                }

                _markIncomingAsRead(docs);

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final docId = docs[index].id;
                    final data = docs[index].data();
                    final senderId = data['senderId'] as String? ?? '';
                    final text = data['text'] as String? ?? '';
                    final isMine = senderId == widget.currentUserId;
                    final sentAt = _safeSentAt(data);
                    final isRead = _safeIsRead(data);
                    final isEdited = data['editedAt'] != null;
                    final tripId = _safeTripId(data);
                    final messageType = _safeType(data);
                    final metadata = _safeMetadata(data);
                    final imageUrl = _safeImageUrl(data);
                    final reactions = _safeReactions(data);
                    final myReaction = reactions[widget.currentUserId] ?? '';
                    final reactionSummary = _summarizeReactions(reactions);
                    final bookingRequestId =
                        (metadata['bookingRequestId'] ?? '').toString().trim();
                    final bool hasBookingAction =
                        bookingRequestId.isNotEmpty || messageType.startsWith('booking_request');

                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: isMine
                            ? () => _showMessageOptions(context, docId, text)
                            : null,
                        onDoubleTap: () => _showReactionPicker(
                          context: context,
                          docId: docId,
                          currentReaction: myReaction,
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 290),
                          decoration: BoxDecoration(
                            color: isMine
                                ? const Color(0xFF1F6F66)
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl,
                                    width: 230,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const SizedBox(
                                        width: 230,
                                        height: 140,
                                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      );
                                    },
                                  ),
                                ),
                              if (text.isNotEmpty) ...[
                                if (imageUrl.isNotEmpty) const SizedBox(height: 8),
                                Text(
                                  text,
                                  style: TextStyle(
                                    color: isMine
                                        ? Colors.white
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isEdited)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Text(
                                        'ред.',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                          color: isMine
                                              ? Colors.white60
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    _formatTime(sentAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMine
                                          ? Colors.white70
                                          : Theme.of(context).hintColor,
                                    ),
                                  ),
                                  if (isMine) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      isRead ? Icons.done_all_rounded : Icons.done_rounded,
                                      size: 14,
                                      color: isRead ? Colors.white : Colors.white70,
                                    ),
                                  ],
                                ],
                              ),
                              if (reactionSummary.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: reactionSummary.entries.map((entry) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isMine
                                            ? Colors.white.withValues(alpha: 0.2)
                                            : Theme.of(context).colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${entry.key} ${entry.value}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isMine
                                              ? Colors.white
                                              : Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              if (isSystemChat) ...[
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    if (hasBookingAction && bookingRequestId.isNotEmpty) {
                                      _openBookingRequestFromMessage(bookingRequestId);
                                      return;
                                    }
                                    _openTripFromMessage(tripId);
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? Colors.white.withValues(alpha: 0.14)
                                           : Theme.of(context).colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isMine
                                            ? Colors.white.withValues(alpha: 0.24)
                                             : Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.route_rounded,
                                          size: 16,
                                           color: isMine
                                               ? Colors.white
                                               : Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: hasBookingAction
                                              ? Text(
                                                  bookingRequestId.isEmpty
                                                      ? 'Переглянути запит бронювання'
                                                      : 'Відкрити запит на бронювання',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isMine
                                                        ? Colors.white
                                                        : Theme.of(context).colorScheme.onSurface,
                                                  ),
                                                )
                                              : tripId.isEmpty
                                              ? Text(
                                                  'Поїздка не вказана',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isMine
                                                        ? Colors.white
                                                        : Theme.of(context).colorScheme.onSurface,
                                                  ),
                                                )
                                              : FutureBuilder<Trip?>(
                                                  future: _tripService.getTripById(tripId),
                                                  builder: (context, tripSnapshot) {
                                                    final trip = tripSnapshot.data;
                                                    final text = trip == null
                                                        ? 'Поїздка: $tripId'
                                                        : _formatTripBadgeText(trip);
                                                    return Text(
                                                      text,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: isMine
                                                            ? Colors.white
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .onSurface,
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                        Icon(
                                          Icons.open_in_new_rounded,
                                          size: 15,
                                          color: isMine
                                              ? Colors.white70
                                              : Theme.of(context).colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              // Прийняття/відхилення виконується на екрані поїздки.
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (!isSystemChat)
            SafeArea(
              top: false,
              child: Container(
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_editingDocId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF1F6F66)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Редагування повiдомлення',
                                style: TextStyle(fontSize: 13, color: Color(0xFF2E7D32)),
                              ),
                            ),
                            GestureDetector(
                              onTap: _cancelEdit,
                              child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        if (_sendingImage)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: 'Фото',
                            onPressed: _pickAndSendImage,
                            icon: const Icon(Icons.photo_library_outlined),
                          ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: _editingDocId != null
                                  ? 'Вiдредагуйте повiдомлення...'
                                  : 'Ваше повiдомлення...',
                              filled: true,
                              fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 44,
                          width: 44,
                          child: ElevatedButton(
                            onPressed: _sendingImage ? null : _sendMessage,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              elevation: 0,
                            ),
                            child: Icon(
                              _editingDocId != null
                                  ? Icons.check_rounded
                                  : Icons.send_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Container(
                color: Theme.of(context).cardColor,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Text(
                  'Системний чат: вiдправка повiдомлень вимкнена',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }
}