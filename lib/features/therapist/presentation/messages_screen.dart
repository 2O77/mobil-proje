import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/subject_provider.dart';
import '../../../core/providers/therapist_dashboard_provider.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  Future<String> _openOrCreate(String other) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || other.isEmpty) return '';
    final cid = conversationIdFor(me, other);
    await FirebaseFirestore.instance.collection('conversations').doc(cid).set({
      'participantIds': [me, other],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return cid;
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mesajlar')),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (session) {
          if (session == null) return const Center(child: Text('Oturum yok'));
          final role = session.profile?.role;
          if (role == AppUserRole.therapist) {
            return _TherapistInbox(onOpenChat: (conversationId) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ChatThreadScreen(conversationId: conversationId)),
              );
            });
          }
          final peerId = session.profile?.linkedTherapistId;
          if (peerId == null || peerId.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aktif mesajlaşma için profilden terapist bağlantısı gerekir.'),
              ),
            );
          }
          return FutureBuilder<String>(
            future: _openOrCreate(peerId),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final conversationId = snap.data!;
              if (conversationId.isEmpty) return const Center(child: Text('Mesajlaşma başlatılamadı.'));
              return ChatThreadScreen(conversationId: conversationId);
            },
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
    final patientsAsync = ref.watch(therapistPatientsProvider);
    return conversationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Mesajlar alınamadı: $e')),
      data: (conversations) {
        return patientsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (patientIds) {
            if (patientIds.isEmpty) {
              return const Center(child: Text('Bağlı danışan yok.'));
            }
            final byPatient = {for (final c in conversations) c.patientId: c};
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: patientIds.length,
              itemBuilder: (_, i) {
                final patientId = patientIds[i];
                final conv = byPatient[patientId];
                final when = conv?.updatedAt == null ? null : DateFormat('dd.MM HH:mm').format(conv!.updatedAt!);
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('users').doc(patientId).get(),
                  builder: (context, snap) {
                    final name = snap.data?.data()?['displayName'] as String? ?? patientId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(name),
                        subtitle: Text(conv?.lastMessageText ?? 'Mesajlaşmaya başlayın'),
                        trailing: when == null ? const Icon(Icons.chevron_right) : Text(when, style: Theme.of(context).textTheme.bodySmall),
                        onTap: () async {
                          final me = FirebaseAuth.instance.currentUser?.uid;
                          if (me == null) return;
                          ref.read(therapistPatientSubjectProvider.notifier).select(patientId);
                          final cid = conv?.conversationId ?? conversationIdFor(me, patientId);
                          if (conv == null) {
                            await FirebaseFirestore.instance.collection('conversations').doc(cid).set({
                              'participantIds': [me, patientId],
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                          }
                          onOpenChat(cid);
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.conversationId, this.embed = false});

  final String conversationId;
  final bool embed;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final text = _text.text.trim();
    if (me == null || text.isEmpty) return;
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
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  final mine = d['senderId'] == me;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: mine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(d['text'] as String? ?? ''),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _text, decoration: const InputDecoration(hintText: 'Mesaj'))),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ),
      ],
    );
    if (widget.embed) return chatBody;
    return Scaffold(
      appBar: AppBar(title: const Text('Sohbet')),
      body: chatBody,
    );
  }
}
