import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessangerScreen extends StatefulWidget {
  const MessangerScreen({super.key});

  @override
  State<MessangerScreen> createState() => _MessangerScreenState();
}

class _MessangerScreenState extends State<MessangerScreen> {
  final Color primaryTurquoise = const Color(0xFF5DD9C1);

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesForUser(String uid) {
    return FirebaseFirestore.instance
        .collection('messages')
        .where(
          Filter.or(
            Filter('senderId', isEqualTo: uid),
            Filter('receiverId', isEqualTo: uid),
          ),
        )
        .snapshots();
  }

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

  Future<Map<String, dynamic>?> _loadUserSummary(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data();
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
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text('Чати', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _messagesForUser(authUser.uid),
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
            ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

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
                future: _loadUserSummary(preview.partnerId),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data ?? const <String, dynamic>{};
                  final userName = (userData['name'] as String?)?.trim();
                  final displayName = (userName == null || userName.isEmpty)
                      ? 'Користувач'
                      : userName;
                  final photoUrl = userData['photoUrl'] as String?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                        backgroundColor: primaryTurquoise.withValues(alpha: 0.15),
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? const Icon(Icons.person, color: Colors.black54)
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

  // Non-null when user is editing an existing message
  String? _editingDocId;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _conversationStream() {
    return FirebaseFirestore.instance
        .collection('messages')
        .where('senderId', whereIn: [widget.currentUserId, widget.partnerId])
        .where('receiverId', whereIn: [widget.currentUserId, widget.partnerId])
        .snapshots();
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

  String _formatTime(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '--:--';
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _markIncomingAsRead(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final updates = docs.where((doc) {
      final data = doc.data();
      final receiverId = data['receiverId'] as String? ?? '';
      return receiverId == widget.currentUserId && !_safeIsRead(data);
    }).toList();

    if (updates.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in updates) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    if (_editingDocId != null) {
      // Save edit
      final docId = _editingDocId!;
      setState(() => _editingDocId = null);
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(docId)
          .update({'text': text, 'editedAt': FieldValue.serverTimestamp()});
      return;
    }

    await FirebaseFirestore.instance.collection('messages').add({
      'tripId': '',
      'senderId': widget.currentUserId,
      'receiverId': widget.partnerId,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
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
      await FirebaseFirestore.instance.collection('messages').doc(docId).delete();
    }
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
                color: Colors.grey.shade300,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: (widget.partnerPhotoUrl != null && widget.partnerPhotoUrl!.isNotEmpty)
                  ? NetworkImage(widget.partnerPhotoUrl!)
                  : null,
              child: (widget.partnerPhotoUrl == null || widget.partnerPhotoUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.partnerName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
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
                    return aDate.compareTo(bDate);
                  });

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Почнiть розмову першим повiдомленням'),
                  );
                }

                _markIncomingAsRead(docs);

                return ListView.builder(
                  controller: _scrollController,
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

                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: isMine
                            ? () => _showMessageOptions(context, docId, text)
                            : null,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 290),
                          decoration: BoxDecoration(
                            color: isMine ? const Color(0xFF5DD9C1) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                text,
                                style: TextStyle(
                                  color: isMine ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
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
                                          color: isMine ? Colors.white60 : Colors.black38,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    _formatTime(sentAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMine ? Colors.white70 : Colors.black45,
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
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_editingDocId != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F7F4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF5DD9C1)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Редагування повiдомлення',
                              style: TextStyle(fontSize: 13, color: Color(0xFF2E7D70)),
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
                            fillColor: const Color(0xFFF1F3F5),
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
                          onPressed: _sendMessage,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                            backgroundColor: const Color(0xFF5DD9C1),
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
          ),
        ],
      ),
    );
  }
}