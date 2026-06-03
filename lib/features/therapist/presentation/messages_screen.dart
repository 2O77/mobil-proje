import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/providers/patient_profile_provider.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/subject_provider.dart';
import '../../../core/providers/therapist_dashboard_provider.dart';
import '../../../core/services/conversation_service.dart';

final patientConversationIdProvider = FutureProvider<String>((ref) async {
  final subjectId = ref.watch(effectiveSubjectIdProvider);
  if (subjectId == null || subjectId.isEmpty) return '';
  final profile = ref.watch(patientProfileProvider(subjectId)).value;
  final therapistId = profile?.linkedTherapistId;
  if (therapistId == null || therapistId.isEmpty) return '';
  return ensureTherapistPatientConversation(therapistId: therapistId, patientId: subjectId);
});

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionStreamProvider);
    return sessionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (session) {
        if (session == null) {
          return const Scaffold(body: Center(child: Text('Oturum yok')));
        }
        if (session.profile?.role == AppUserRole.therapist) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mesajlar')),
            body: _TherapistInbox(
              onOpenChat: (conversationId) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatThreadScreen(conversationId: conversationId)),
                );
              },
            ),
          );
        }
        return const _PatientMessagesScreen();
      },
    );
  }
}

class _PatientMessagesScreen extends ConsumerWidget {
  const _PatientMessagesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationAsync = ref.watch(patientConversationIdProvider);
    final subjectId = ref.watch(effectiveSubjectIdProvider);
    final therapistId = subjectId == null
        ? null
        : ref.watch(patientProfileProvider(subjectId)).value?.linkedTherapistId;

    return Scaffold(
      appBar: AppBar(
        title: therapistId == null
            ? const Text('Mesajlar')
            : ref.watch(patientProfileProvider(therapistId)).maybeWhen(
                  data: (p) => Text(p.displayName ?? 'Terapist'),
                  orElse: () => const Text('Mesajlar'),
                ),
      ),
      resizeToAvoidBottomInset: true,
      body: conversationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Mesajlaşma açılamadı: $e')),
        data: (conversationId) {
          if (conversationId.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aktif mesajlaşma için ayarlardan terapist bağlantısı gerekir.'),
              ),
            );
          }
          return SizedBox.expand(
            child: ChatThreadScreen(conversationId: conversationId, embed: true),
          );
        },
      ),
    );
  }
}

class _TherapistInbox extends ConsumerWidget {
  const _TherapistInbox({required this.onOpenChat});

  final void Function(String conversationId) onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(therapistConversationsProvider);
    return conversationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Mesajlar alınamadı: $e')),
      data: (conversations) {
        if (conversations.isEmpty) {
          return const Center(child: Text('Bağlı danışan yok.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: conversations.length,
          itemBuilder: (_, i) {
            final conv = conversations[i];
            final when = conv.updatedAt == null ? null : DateFormat('dd.MM HH:mm').format(conv.updatedAt!);
            return _InboxTile(conversation: conv, when: when, onOpenChat: onOpenChat);
          },
        );
      },
    );
  }
}

class _InboxTile extends ConsumerWidget {
  const _InboxTile({
    required this.conversation,
    required this.when,
    required this.onOpenChat,
  });

  final TherapistConversationPreview conversation;
  final String? when;
  final void Function(String conversationId) onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(patientProfileProvider(conversation.patientId));
    final name = profileAsync.value?.displayName ?? 'Danışan';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.chat_bubble_outline),
        title: Text(name),
        subtitle: Text(conversation.lastMessageText ?? 'Mesajlaşmaya başlayın'),
        trailing: when == null ? const Icon(Icons.chevron_right) : Text(when!, style: Theme.of(context).textTheme.bodySmall),
        onTap: () {
          ref.read(therapistPatientSubjectProvider.notifier).select(conversation.patientId);
          onOpenChat(conversation.conversationId);
        },
      ),
    );
  }
}

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    this.embed = false,
    this.readOnly = false,
  });

  final String conversationId;
  final bool embed;
  final bool readOnly;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _text = TextEditingController();
  final _scrollController = ScrollController();
  var _sending = false;

  @override
  void dispose() {
    _text.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final text = _text.text.trim();
    if (me == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .add({
        'senderId': me,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('conversations').doc(widget.conversationId).update({
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageText': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      _text.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final q = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false);
    final chatBody = Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Mesajlar alınamadı: ${snap.error}'));
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Text(widget.readOnly ? 'Henüz mesaj yok.' : 'Henüz mesaj yok. İlk mesajı gönderin.'),
                );
              }
              _scrollToBottom();
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  final mine = d['senderId'] == me;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: mine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(d['text'] as String? ?? ''),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (!widget.readOnly)
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Mesaj yazın',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    if (widget.embed) return SizedBox.expand(child: chatBody);
    return Scaffold(
      appBar: AppBar(title: const Text('Sohbet')),
      resizeToAvoidBottomInset: true,
      body: chatBody,
    );
  }
}
