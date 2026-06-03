import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/daily_log.dart';
import '../../../core/models/sos_event.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/patient_profile_provider.dart';
import '../../../core/providers/sos_alert_provider.dart';
import '../../../core/providers/subject_provider.dart';
import 'sos_pulse_indicator.dart';
import '../../../core/services/conversation_service.dart';
import 'messages_screen.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  const PatientDetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(therapistPatientSubjectProvider.notifier).select(widget.patientId);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(patientProfileProvider(widget.patientId));
    final profile = profileAsync.value ?? UserProfile(uid: widget.patientId);
    final name = profile.displayName ?? 'Danışan';
    final showClinicalHeader = _tabs.index != 3;
    final hasActiveSos = ref.watch(patientHasActiveSosProvider(widget.patientId));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(name),
        actions: [
          if (hasActiveSos)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SosPulseIndicator()),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Günlük'),
            Tab(text: 'SOS'),
            Tab(text: 'Raporlar'),
            Tab(text: 'Mesaj'),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showClinicalHeader)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty)
                    Text('Telefon: ${profile.phoneNumber}'),
                  if (profile.diagnosisNotes != null && profile.diagnosisNotes!.isNotEmpty)
                    Text('Tanı: ${profile.diagnosisNotes}'),
                  if (profile.medications.isNotEmpty)
                    Text('İlaçlar: ${profile.medications.join(', ')}'),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _tabs.index,
              children: [
                _DailyLogsTab(patientId: widget.patientId),
                _SosTab(patientId: widget.patientId),
                _ReportsTab(patientId: widget.patientId),
                _MessageTab(patientId: widget.patientId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyLogsTab extends StatelessWidget {
  const _DailyLogsTab({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance.collection('daily_logs').where('userId', isEqualTo: patientId).limit(50);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Günlük kayıtları alınamadı: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = [...snap.data!.docs]..sort((a, b) {
            final aKey = a.data()['dateKey'] as String? ?? '';
            final bKey = b.data()['dateKey'] as String? ?? '';
            return bKey.compareTo(aKey);
          });
        if (docs.isEmpty) return const Center(child: Text('Günlük kaydı yok.'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final log = DailyLog.fromDoc(docs[i]);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(log.dateKey),
                subtitle: Text(
                  [
                    if (log.moodEmoji != null) 'Ruh hali: ${log.moodEmoji}',
                    if (log.stress1to10 != null) 'Stres: ${log.stress1to10}/10',
                    if (log.note != null && log.note!.isNotEmpty) log.note,
                  ].join(' • '),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SosTab extends ConsumerWidget {
  const _SosTab({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = FirebaseFirestore.instance.collection('sos_events').where('userId', isEqualTo: patientId).limit(50);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('SOS kayıtları alınamadı: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = [...snap.data!.docs]..sort((a, b) {
            final aTs = a.data()['createdAt'];
            final bTs = b.data()['createdAt'];
            if (aTs is! Timestamp && bTs is! Timestamp) return 0;
            if (aTs is! Timestamp) return 1;
            if (bTs is! Timestamp) return -1;
            return bTs.compareTo(aTs);
          });
        if (docs.isEmpty) return const Center(child: Text('SOS kaydı yok.'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final event = SosEvent.fromDoc(docs[i]);
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
                title: Text(isActive ? 'Aktif SOS — $when' : 'Kayıt — $when'),
                subtitle: Text(loc),
                trailing: isActive
                    ? TextButton(
                        onPressed: () async {
                          final result = await tryAcknowledgeSosEvent(event.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.ok
                                    ? 'SOS görüldü olarak işaretlendi'
                                    : 'SOS güncellenemedi: ${result.error ?? 'bilinmeyen hata'}',
                              ),
                            ),
                          );
                        },
                        child: const Text('Görüldü'),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final sessionReportsQuery =
        FirebaseFirestore.instance.collection('session_reports').where('subjectUserId', isEqualTo: patientId).limit(50);
    final assessmentsQuery =
        FirebaseFirestore.instance.collection('assessments').where('subjectUserId', isEqualTo: patientId).limit(50);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Seans raporları', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: sessionReportsQuery.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return Text('Seans raporları alınamadı: ${snap.error}');
            if (!snap.hasData) return const LinearProgressIndicator();
            final docs = [...snap.data!.docs]..sort((a, b) {
                final aTs = a.data()['createdAt'];
                final bTs = b.data()['createdAt'];
                if (aTs is! Timestamp && bTs is! Timestamp) return 0;
                if (aTs is! Timestamp) return 1;
                if (bTs is! Timestamp) return -1;
                return bTs.compareTo(aTs);
              });
            if (docs.isEmpty) return const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Seans raporu yok.'));
            return Column(
              children: docs.map((d) {
                final data = d.data();
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text((data['title'] as String?) ?? 'Rapor'),
                    subtitle: Text((data['body'] as String?) ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        const Text('Değerlendirmeler', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: assessmentsQuery.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return Text('Değerlendirmeler alınamadı: ${snap.error}');
            if (!snap.hasData) return const LinearProgressIndicator();
            final docs = [...snap.data!.docs]..sort((a, b) {
                final aTs = a.data()['createdAt'];
                final bTs = b.data()['createdAt'];
                if (aTs is! Timestamp && bTs is! Timestamp) return 0;
                if (aTs is! Timestamp) return 1;
                if (bTs is! Timestamp) return -1;
                return bTs.compareTo(aTs);
              });
            if (docs.isEmpty) return const Text('Değerlendirme yok.');
            return Column(
              children: docs.map((d) {
                final data = d.data();
                final answers = (data['answers'] as Map<String, dynamic>?) ?? const {};
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text((data['type'] as String?) ?? 'assessment'),
                    subtitle: Text('${answers.length} cevap kaydı'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _MessageTab extends ConsumerStatefulWidget {
  const _MessageTab({required this.patientId});

  final String patientId;

  @override
  ConsumerState<_MessageTab> createState() => _MessageTabState();
}

class _MessageTabState extends ConsumerState<_MessageTab> {
  String? _conversationId;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  Future<void> _initConversation() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final cid = await ensureTherapistPatientConversation(therapistId: me, patientId: widget.patientId);
    if (mounted) {
      setState(() {
        _conversationId = cid;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_conversationId == null || _conversationId!.isEmpty) {
      return const Center(child: Text('Mesajlaşma başlatılamadı.'));
    }
    return SizedBox.expand(
      child: ChatThreadScreen(conversationId: _conversationId!, embed: true),
    );
  }
}
