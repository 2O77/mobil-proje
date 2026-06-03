import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/sos_event.dart';
import '../../../core/providers/patient_profile_provider.dart';
import '../../../core/providers/sos_alert_provider.dart';
import '../../../core/providers/subject_provider.dart';

class TherapistSosScreen extends ConsumerWidget {
  const TherapistSosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(effectiveSubjectIdProvider);
    final activeAsync = ref.watch(therapistActiveSosProvider);
    final subjectName = subject == null ? null : ref.watch(patientProfileProvider(subject)).value?.displayName;
    return Scaffold(
      appBar: AppBar(title: const Text('SOS Olayları')),
      body: subject == null
          ? const Center(child: CircularProgressIndicator())
          : activeAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (activeEvents) {
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (activeEvents.isNotEmpty) ...[
                      Text('Aktif alarmlar', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...activeEvents.map((event) => _ActiveSosCard(event: event)),
                      const Divider(height: 32),
                      Text('Geçmiş kayıtlar — ${subjectName ?? 'Danışan'}', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                    ],
                    _SosEventsList(subjectId: subject),
                  ],
                );
              },
            ),
    );
  }
}

class _ActiveSosCard extends ConsumerWidget {
  const _ActiveSosCard({required this.event});

  final SosEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final when = event.createdAt == null ? '-' : DateFormat('dd.MM.yyyy HH:mm').format(event.createdAt!);
    final loc = event.lat == null || event.lng == null ? 'Konum yok' : '${event.lat}, ${event.lng}';
    final name = ref.watch(patientProfileProvider(event.userId)).value?.displayName ?? 'Danışan';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
        title: Text(
          '$name — $when',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        subtitle: Text(loc, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
        trailing: TextButton(
          onPressed: () => acknowledgeSosEvent(event.id),
          child: const Text('Görüldü'),
        ),
        onTap: () => ref.read(therapistPatientSubjectProvider.notifier).select(event.userId),
      ),
    );
  }
}

class _SosEventsList extends StatelessWidget {
  const _SosEventsList({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance.collection('sos_events').where('userId', isEqualTo: subjectId).limit(50);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('SOS kayıtları alınamadı: ${snap.error}'),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = [...snap.data!.docs]..sort((a, b) {
            final aTs = a.data()['createdAt'];
            final bTs = b.data()['createdAt'];
            if (aTs is! Timestamp && bTs is! Timestamp) return 0;
            if (aTs is! Timestamp) return 1;
            if (bTs is! Timestamp) return -1;
            return bTs.compareTo(aTs);
          });
        if (docs.isEmpty) {
          return Center(
            child: Text('Bu danışan için SOS kaydı yok.', style: Theme.of(context).textTheme.bodyLarge),
          );
        }
        return Column(
          children: docs.map((doc) {
            final event = SosEvent.fromDoc(doc);
            final when = event.createdAt == null ? '-' : DateFormat('dd.MM.yyyy HH:mm').format(event.createdAt!);
            final loc = event.lat == null || event.lng == null ? 'Konum yok' : '${event.lat}, ${event.lng}';
            final isActive = event.isActive;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isActive ? Theme.of(context).colorScheme.errorContainer : null,
              child: ListTile(
                leading: Icon(
                  isActive ? Icons.warning_amber_rounded : Icons.history,
                  color: isActive ? Theme.of(context).colorScheme.onErrorContainer : null,
                ),
                title: Text(
                  isActive ? 'SOS - $when' : 'Kayıt - $when',
                  style: isActive
                      ? TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        )
                      : null,
                ),
                subtitle: Text(
                  loc,
                  style: isActive ? TextStyle(color: Theme.of(context).colorScheme.onErrorContainer) : null,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
