import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/patient_profile_provider.dart';
import '../../../core/providers/sos_alert_provider.dart';
import '../../../core/providers/subject_provider.dart';
import 'patient_detail_screen.dart';

class TherapistPatientsScreen extends ConsumerWidget {
  const TherapistPatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(therapistPatientsProvider);
    final selected = ref.watch(therapistPatientSubjectProvider);
    final activePatientIds = ref.watch(activeSosPatientIdsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Danışanlarım')),
      body: patientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ids) {
          if (ids.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Size bağlı danışan yok. Danışan ayarlardan sizi terapist olarak seçmelidir.'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: ids.length,
            itemBuilder: (context, i) {
              final patientId = ids[i];
              return _PatientListTile(
                patientId: patientId,
                hasActiveSos: activePatientIds.contains(patientId),
                picked: selected == patientId || (selected == null && i == 0),
                onTap: () {
                  ref.read(therapistPatientSubjectProvider.notifier).select(patientId);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PatientDetailScreen(patientId: patientId)),
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

class _PatientListTile extends ConsumerWidget {
  const _PatientListTile({
    required this.patientId,
    required this.hasActiveSos,
    required this.picked,
    required this.onTap,
  });

  final String patientId;
  final bool hasActiveSos;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(patientProfileProvider(patientId));
    final displayName = profileAsync.value?.displayName ?? 'Danışan';
    final phone = profileAsync.value?.phoneNumber;
    final avatarText = displayName.isEmpty ? '?' : displayName.substring(0, 1);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: hasActiveSos ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasActiveSos ? Theme.of(context).colorScheme.error : null,
          child: Text(avatarText),
        ),
        title: Row(
          children: [
            Expanded(child: Text(displayName)),
            if (hasActiveSos)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'SOS aktif',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: phone != null && phone.isNotEmpty ? Text(phone) : null,
        trailing: picked ? const Icon(Icons.check_circle) : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
