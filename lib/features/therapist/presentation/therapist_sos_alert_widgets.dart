import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/sos_event.dart';
import '../../../core/providers/patient_profile_provider.dart';
import '../../../core/providers/sos_alert_provider.dart';

class TherapistSosAlertBanner extends ConsumerWidget {
  const TherapistSosAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(therapistActiveSosProvider);
    return alertsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();
        final latest = events.first;
        final profileAsync = ref.watch(patientProfileProvider(latest.userId));
        final name = profileAsync.value?.displayName ?? 'Danışan';
        final when = latest.createdAt == null ? '' : DateFormat('dd.MM.yyyy HH:mm').format(latest.createdAt!);
        return Material(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        events.length == 1 ? 'Aktif SOS alarmı' : '${events.length} aktif SOS alarmı',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                      ),
                      Text(
                        '$name${when.isEmpty ? '' : ' • $when'}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => openTherapistSosAlert(ref, patientId: latest.userId),
                  child: const Text('SOS'),
                ),
                TextButton(
                  onPressed: () => acknowledgeSosEvent(latest.id),
                  child: const Text('Görüldü'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TherapistSosProfileAlertCard extends ConsumerWidget {
  const TherapistSosProfileAlertCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(therapistActiveSosProvider);
    return alertsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();
        return Card(
          color: Theme.of(context).colorScheme.errorContainer,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        events.length == 1 ? 'SOS alarmı var' : '${events.length} SOS alarmı var',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...events.take(3).map((event) => _SosAlertRow(event: event)),
                if (events.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+${events.length - 3} alarm daha',
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SosAlertRow extends ConsumerWidget {
  const _SosAlertRow({required this.event});

  final SosEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final when = event.createdAt == null ? '-' : DateFormat('dd.MM.yyyy HH:mm').format(event.createdAt!);
    final profileAsync = ref.watch(patientProfileProvider(event.userId));
    final name = profileAsync.value?.displayName ?? 'Danışan';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$name • $when',
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: () => openTherapistSosAlert(ref, patientId: event.userId),
            child: const Text('Git'),
          ),
          TextButton(
            onPressed: () => acknowledgeSosEvent(event.id),
            child: const Text('Görüldü'),
          ),
        ],
      ),
    );
  }
}
