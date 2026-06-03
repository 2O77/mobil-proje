import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/daily_log.dart';
import '../../../core/models/sos_event.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/sos_alert_provider.dart';
import '../../../core/providers/subject_provider.dart';
import '../../../core/providers/therapist_dashboard_provider.dart';
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.patientId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final profile = snap.data!.exists
            ? UserProfile.fromDoc(widget.patientId, snap.data!.data()!)
            : UserProfile(uid: widget.patientId);
        final name = profile.displayName ?? 'Danışan';
        return Scaffold(
          appBar: AppBar(
            title: Text(name),
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
                child: TabBarView(
                  controller: _tabs,
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
      },
    );
  }
}

class _DailyLogsTab extends StatelessWidget {
  const _DailyLogsTab({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('daily_logs')
        .where('userId', isEqualTo: patientId)
        .orderBy('dateKey', descending: true)
        .limit(30);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Günlük kayıtları alınamadı: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
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
    final query = FirebaseFirestore.instance
        .collection('sos_events')
        .where('userId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .limit(50);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('SOS kayıtları alınamadı: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
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
                    ? TextButton(onPressed: () => acknowledgeSosEvent(event.id), child: const Text('Görüldü'))
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
    final sessionReportsQuery = FirebaseFirestore.instance
        .collection('session_reports')
        .where('subjectUserId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .limit(50);
    final assessmentsQuery = FirebaseFirestore.instance
        .collection('assessments')
        .where('subjectUserId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .limit(50);

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
            final docs = snap.data!.docs;
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
            final docs = snap.data!.docs;
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
  Future<String>? _conversationFuture;

  @override
  void initState() {
    super.initState();
    _conversationFuture = _openOrCreate();
  }

  Future<String> _openOrCreate() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return '';
    final cid = conversationIdFor(me, widget.patientId);
    await FirebaseFirestore.instance.collection('conversations').doc(cid).set({
      'participantIds': [me, widget.patientId],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return cid;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _conversationFuture,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final conversationId = snap.data!;
        if (conversationId.isEmpty) return const Center(child: Text('Mesajlaşma başlatılamadı.'));
        return ChatThreadScreen(conversationId: conversationId, embed: true);
      },
    );
  }
}
