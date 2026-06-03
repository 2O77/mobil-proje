import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/subject_provider.dart';
import '../../../core/providers/therapists_directory_provider.dart';
import '../../therapist/presentation/therapist_sos_alert_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _diagnosis = TextEditingController();
  final _meds = TextEditingController();
  String? _therapistSelection;
  final _caregiver = TextEditingController();
  var _busy = false;
  String? _hydratedUid;

  void _hydrateFieldsFromProfile(String uid, UserProfile? p) {
    if (p == null || _hydratedUid == uid) return;
    _name.text = p.displayName ?? '';
    _diagnosis.text = p.diagnosisNotes ?? '';
    _meds.text = p.medications.join(', ');
    _therapistSelection = p.linkedTherapistId;
    _caregiver.clear();
    _hydratedUid = uid;
  }

  @override
  void dispose() {
    _name.dispose();
    _diagnosis.dispose();
    _meds.dispose();
    _caregiver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (session) {
          if (session == null) return const Center(child: Text('Oturum yok'));
          final p = session.profile;
          final uid = session.user.uid;
          _hydrateFieldsFromProfile(uid, p);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (p?.role == AppUserRole.therapist) const TherapistSosProfileAlertCard(),
              ListTile(
                leading: CircleAvatar(radius: 28, child: Text(uid.substring(0, 2))),
                title: const Text('Hesap'),
              ),
              Text('UID: $uid', style: Theme.of(context).textTheme.bodySmall),
              const Divider(),
              const SizedBox(height: 8),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Görünen ad')),
              const SizedBox(height: 16),
              TextField(controller: _diagnosis, maxLines: 3, decoration: const InputDecoration(labelText: 'Tanı / notlar')),
              const SizedBox(height: 16),
              TextField(controller: _meds, decoration: const InputDecoration(labelText: 'İlaçlar (virgülle)')),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : () => _saveProfile(uid),
                child: const Text('Profili kaydet'),
              ),
              const Divider(height: 32),
              const SizedBox(height: 8),
              ref.watch(therapistsDirectoryProvider).when(
                data: (list) {
                  if (list.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Terapist listesi henüz hazır değil.'),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => ref.invalidate(therapistsDirectoryProvider),
                          child: const Text('Yeniden dene'),
                        ),
                      ],
                    );
                  }
                  final linked = p?.linkedTherapistId;
                  final items = <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('Terapist seçin')),
                    ...list.map(
                      (e) => DropdownMenuItem<String?>(value: e.uid, child: Text(e.displayName)),
                    ),
                    if (linked != null && !list.any((e) => e.uid == linked))
                      DropdownMenuItem<String?>(
                        value: linked,
                        child: Text('Kayıtlı bağlantı ($linked)'),
                      ),
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String?>(
                        value: _therapistSelection,
                        decoration: const InputDecoration(labelText: 'Bağlı terapist'),
                        items: items,
                        onChanged: (v) => setState(() => _therapistSelection = v),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: _busy ? null : () => _linkTherapist(uid),
                        child: const Text('Terapist bağlantısını kaydet'),
                      ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Terapistler yukleniyor...'),
                    ],
                  ),
                ),
                error: (e, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Terapist listesi alinamadi: $e',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(therapistsDirectoryProvider),
                      child: const Text('Yeniden dene'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(controller: _caregiver, decoration: const InputDecoration(labelText: 'Bakım veren UID (birey hesabı)')),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _busy ? null : () => _addCaregiver(uid),
                child: const Text('Bakım veren ekle'),
              ),
              const Divider(height: 32),
              _SubjectSwitcher(profile: p),
              const Divider(height: 32),
              TextButton(
                onPressed: () async {
                  ref.read(selectedSubjectIdProvider.notifier).select(null);
                  ref.read(therapistPatientSubjectProvider.notifier).select(null);
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Çıkış yap'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveProfile(String uid) async {
    setState(() => _busy = true);
    try {
      final meds = _meds.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': _name.text.trim(),
        'diagnosisNotes': _diagnosis.text.trim(),
        'medications': meds,
      }, SetOptions(merge: true));
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
      }
      await FirebaseMessaging.instance.requestPermission();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkTherapist(String uid) async {
    setState(() => _busy = true);
    try {
      if (_therapistSelection == null || _therapistSelection!.isEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'linkedTherapistId': FieldValue.delete(),
        }, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'linkedTherapistId': _therapistSelection,
        }, SetOptions(merge: true));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCaregiver(String uid) async {
    final id = _caregiver.text.trim();
    if (id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'caregiverIds': FieldValue.arrayUnion([id]),
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SubjectSwitcher extends ConsumerWidget {
  const _SubjectSwitcher({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = profile?.role;
    if (role == AppUserRole.caregiver) {
      final kids = ref.watch(caregiverSubjectsProvider);
      return kids.when(
        data: (list) {
          if (list.isEmpty) {
            return const Text('Bağlı birey bulunamadı. Birey hesabından bakım veren olarak sizi eklemesi gerekir.');
          }
          final sel = ref.watch(selectedSubjectIdProvider);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Veri girişi için birey', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: sel != null && list.contains(sel) ? sel : list.first,
                items: list.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) {
                  if (v != null) ref.read(selectedSubjectIdProvider.notifier).select(v);
                },
              ),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('$e'),
      );
    }
    if (role == AppUserRole.therapist) {
      final pts = ref.watch(therapistPatientsProvider);
      return pts.when(
        data: (list) {
          if (list.isEmpty) {
            return const Text('Bağlı danışan yok. Danışan, profilden listedeki terapistlerden sizi seçerek bağlamalıdır.');
          }
          final sel = ref.watch(therapistPatientSubjectProvider);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('İzlenen danışan', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: sel != null && list.contains(sel) ? sel : list.first,
                items: list.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) {
                  if (v != null) ref.read(therapistPatientSubjectProvider.notifier).select(v);
                },
              ),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('$e'),
      );
    }
    return const SizedBox.shrink();
  }
}
