import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/subject_provider.dart';

String _conversationId(String a, String b) {
  final list = [a, b]..sort();
  return '${list[0]}__${list[1]}';
}

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  Future<String> _openOrCreate(String other) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || other.isEmpty) return '';
    final cid = _conversationId(me, other);
    await FirebaseFirestore.instance.collection('conversations').doc(cid).set({
      'participantIds': [me, other],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return cid;
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionStreamProvider);
    final selectedSubjectId = ref.watch(effectiveSubjectIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mesajlar')),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (session) {
          if (session == null) return const Center(child: Text('Oturum yok'));
          final me = session.user.uid;
          final role = session.profile?.role;
          String? peerId;

          if (role == AppUserRole.therapist) {
            peerId = selectedSubjectId == me ? null : selectedSubjectId;
          } else {
            peerId = session.profile?.linkedTherapistId;
          }
          if (peerId == null || peerId.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aktif mesajlasma icin gecerli bir terapist/danisan baglantisi bulunamadi.'),
              ),
            );
          }
          return FutureBuilder<String>(
            future: _openOrCreate(peerId),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final conversationId = snap.data!;
              if (conversationId.isEmpty) return const Center(child: Text('Mesajlasma baslatilamadi.'));
              return ChatThreadScreen(conversationId: conversationId);
            },
          );
        },
      ),
    );
  }
}

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.conversationId});

  final String conversationId;

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
    if (me == null || _text.text.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .add({
      'senderId': me,
      'text': _text.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('conversations').doc(widget.conversationId).update({
      'updatedAt': FieldValue.serverTimestamp(),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Sohbet')),
      body: Column(
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
                          color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
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
      ),
    );
  }
}
