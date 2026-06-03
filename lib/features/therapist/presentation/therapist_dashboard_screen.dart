import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/patient_profile_provider.dart';
import '../../../core/providers/sos_alert_provider.dart';
import '../../../core/providers/subject_provider.dart';
import '../../../core/providers/therapist_dashboard_provider.dart';
import 'messages_screen.dart';
import 'therapist_sos_alert_widgets.dart';

class TherapistDashboardScreen extends ConsumerWidget {
  const TherapistDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(therapistPatientsProvider);
    final conversationsAsync = ref.watch(therapistConversationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Özet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TherapistSosProfileAlertCard(),
          const SizedBox(height: 16),
          patientsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (ids) => Card(
              child: ListTile(
                leading: const Icon(Icons.groups),
                title: Text('${ids.length} bağlı danışan'),
                subtitle: const Text('Danışanlar sekmesinden detaylara ulaşın'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ref.read(therapistHomeTabProvider.notifier).select(1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mesajlar', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: () => ref.read(therapistHomeTabProvider.notifier).select(2),
                child: const Text('Tümü'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          conversationsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Mesajlar alınamadı: $e'),
            data: (conversations) {
              if (conversations.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Bağlı danışan yok.'),
                  ),
                );
              }
              return Column(
                children: conversations.take(5).map((c) {
                  final when = c.updatedAt == null ? '' : DateFormat('dd.MM HH:mm').format(c.updatedAt!);
                  return _PatientConversationTile(conversation: c, when: when);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PatientConversationTile extends ConsumerWidget {
  const _PatientConversationTile({required this.conversation, required this.when});

  final TherapistConversationPreview conversation;
  final String when;

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
        trailing: when.isEmpty ? null : Text(when, style: Theme.of(context).textTheme.bodySmall),
        onTap: () {
          ref.read(therapistPatientSubjectProvider.notifier).select(conversation.patientId);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatThreadScreen(conversationId: conversation.conversationId),
            ),
          );
        },
      ),
    );
  }
}
