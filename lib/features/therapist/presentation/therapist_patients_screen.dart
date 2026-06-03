import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/patient_profile_provider.dart';
import '../../../core/providers/sos_alert_provider.dart';
import '../../../core/providers/subject_provider.dart';
import 'patient_detail_screen.dart';
import 'sos_pulse_indicator.dart';

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
          final sortedIds = [...ids]..sort((a, b) {
              final aSos = activePatientIds.contains(a);
              final bSos = activePatientIds.contains(b);
              if (aSos == bSos) return 0;
              return aSos ? -1 : 1;
            });
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: sortedIds.length,
            itemBuilder: (context, i) {
              final patientId = sortedIds[i];
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(avatarText)),
              title: Text(displayName),
              subtitle: phone != null && phone.isNotEmpty ? Text(phone) : null,
              trailing: picked ? const Icon(Icons.check_circle) : const Icon(Icons.chevron_right),
              onTap: onTap,
            ),
          ),
          if (hasActiveSos)
            const Positioned(
              top: 10,
              right: 10,
              child: SosPulseIndicator(),
            ),
        ],
      ),
    );
  }
}
