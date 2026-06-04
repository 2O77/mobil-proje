import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/subject_provider.dart';
import '../../../core/providers/therapists_directory_provider.dart';
import '../../../core/services/conversation_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _therapistSelection;
  var _busy = false;
  String? _hydratedUid;

  void _hydrateFieldsFromProfile(String uid, UserProfile? p) {
    if (p == null || _hydratedUid == uid) return;
    _name.text = p.displayName ?? '';
    _phone.text = p.phoneNumber ?? '';
    _therapistSelection = p.linkedTherapistId;
    _hydratedUid = uid;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool _isPatientRole(AppUserRole? role) => role == AppUserRole.individual;

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (session) {
          if (session == null) return const Center(child: Text('Oturum yok'));
          final p = session.profile;
          final uid = session.user.uid;
          final role = p?.role;
          _hydrateFieldsFromProfile(uid, p);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: CircleAvatar(
                  radius: 28,
                  child: Text((_name.text.isNotEmpty ? _name.text : uid).substring(0, 1).toUpperCase()),
                ),
                title: Text(_name.text.isNotEmpty ? _name.text : 'Hesap'),
                subtitle: Text(session.user.email ?? 'E-posta yok'),
              ),
              const Divider(),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Görünen ad')),
              const SizedBox(height: 16),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon numarası'),
              ),
              const SizedBox(height: 16),
              TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'E-posta',
                  hintText: session.user.email ?? '-',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : () => _saveProfile(uid, role),
                child: const Text('Kaydet'),
              ),
              if (_isPatientRole(role)) ...[
                const Divider(height: 32),
                Text(
                  'İlaçları Takvim → İlaçlar sekmesinden saatleriyle birlikte ekleyin.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                const Divider(height: 32),
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
                          initialValue: _therapistSelection,
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
                        Text('Terapistler yükleniyor...'),
                      ],
                    ),
                  ),
                  error: (e, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Terapist listesi alınamadı: $e',
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
              ],
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

  Future<void> _saveProfile(String uid, AppUserRole? role) async {
    setState(() => _busy = true);
    try {
      final data = <String, dynamic>{
        'displayName': _name.text.trim(),
        'phoneNumber': _phone.text.trim(),
      };
      if (_isPatientRole(role)) {
        data['medications'] = <String>[];
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).set(data, SetOptions(merge: true));
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
        await ensureTherapistPatientConversation(
          therapistId: _therapistSelection!,
          patientId: uid,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
