import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/medication.dart';
import '../../../core/models/daily_log.dart';
import '../../../core/models/sos_event.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/therapist_clinical_provider.dart';
import '../../../core/providers/patient_profile_provider.dart';
import '../../../core/providers/sos_alert_provider.dart';
import '../../../core/providers/subject_provider.dart';
import 'sos_pulse_indicator.dart';
import '../../../core/services/conversation_service.dart';
import '../../../core/services/session_report_pdf_service.dart';
import '../../../core/services/sos_location_service.dart';
import 'messages_screen.dart';
import 'session_report_card.dart';

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
    _tabs = TabController(length: 5, vsync: this);
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
    final clinicalAsync = ref.watch(therapistClinicalProvider(widget.patientId));
    final showClinicalHeader = _tabs.index != 4;
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
            Tab(text: 'Klinik'),
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
                  clinicalAsync.when(
                    data: (record) {
                      if (record == null || record.diagnosis.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Tanı: ${record.diagnosis}'),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  _PatientMedicationsLine(patientId: widget.patientId),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _tabs.index,
              children: [
                _DailyLogsTab(patientId: widget.patientId),
                _ClinicalTab(patientId: widget.patientId),
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

class _PatientMedicationsLine extends StatelessWidget {
  const _PatientMedicationsLine({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('medications').where('userId', isEqualTo: patientId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
        final labels = snap.data!.docs.map((d) {
          final med = Medication.fromDoc(d);
          final times = med.timesLabel.isEmpty ? 'saat yok' : med.timesLabel;
          return '${med.name} ($times)';
        }).join(', ');
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('İlaçlar: $labels'),
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
            final loc = formatSosCoordinates(event.lat, event.lng);
            final mapsUrl = sosMapsUrl(event.lat, event.lng);
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
                subtitle: Text('Konum: $loc'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (mapsUrl != null)
                      IconButton(
                        icon: const Icon(Icons.map_outlined),
                        tooltip: 'Haritada aç',
                        onPressed: () => launchUrl(Uri.parse(mapsUrl)),
                      ),
                    if (isActive)
                      TextButton(
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
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportsTab extends StatefulWidget {
  const _ReportsTab({required this.patientId});

  final String patientId;

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  final _title = TextEditingController(text: 'Seans özeti');
  final _body = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _sendReport() async {
    if (_saving) return;
    final me = FirebaseAuth.instance.currentUser?.uid;
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (me == null || title.isEmpty || body.isEmpty) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('session_reports').add({
        'subjectUserId': widget.patientId,
        'authorId': me,
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await openSessionReportPdf(title: title, body: body, sessionDate: DateTime.now());
      if (!mounted) return;
      _body.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seans raporu gönderildi')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gönderilemedi: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionReportsQuery = FirebaseFirestore.instance
        .collection('session_reports')
        .where('subjectUserId', isEqualTo: widget.patientId)
        .limit(50);
    final assessmentsQuery = FirebaseFirestore.instance
        .collection('assessments')
        .where('subjectUserId', isEqualTo: widget.patientId)
        .limit(50);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Seans raporu gönder', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Başlık')),
        const SizedBox(height: 12),
        TextField(controller: _body, maxLines: 6, decoration: const InputDecoration(labelText: 'Rapor metni')),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _sendReport,
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_outlined),
          label: Text(_saving ? 'Gönderiliyor...' : 'Danışana gönder'),
        ),
        const Divider(height: 32),
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
              children: docs.map((d) => SessionReportCard.fromDoc(d)).toList(),
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

class _ClinicalTab extends ConsumerStatefulWidget {
  const _ClinicalTab({required this.patientId});

  final String patientId;

  @override
  ConsumerState<_ClinicalTab> createState() => _ClinicalTabState();
}

class _ClinicalTabState extends ConsumerState<_ClinicalTab> {
  final _diagnosis = TextEditingController();
  final _note = TextEditingController();
  var _savingDiagnosis = false;
  var _addingNote = false;
  String? _loadedDiagnosis;

  @override
  void initState() {
    super.initState();
    ref.listenManual(therapistClinicalProvider(widget.patientId), (previous, next) {
      next.whenData((record) {
        final diagnosis = record?.diagnosis ?? '';
        if (_loadedDiagnosis == diagnosis) return;
        _loadedDiagnosis = diagnosis;
        _diagnosis.text = diagnosis;
      });
    });
  }

  @override
  void dispose() {
    _diagnosis.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _saveDiagnosis() async {
    if (_savingDiagnosis) return;
    setState(() => _savingDiagnosis = true);
    try {
      await saveTherapistDiagnosis(patientId: widget.patientId, diagnosis: _diagnosis.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanı kaydedildi')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
    } finally {
      if (mounted) setState(() => _savingDiagnosis = false);
    }
  }

  Future<void> _addNote() async {
    final text = _note.text.trim();
    if (text.isEmpty || _addingNote) return;
    setState(() => _addingNote = true);
    try {
      await addTherapistClinicalNote(patientId: widget.patientId, text: text);
      _note.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not eklendi')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not eklenemedi: $e')));
    } finally {
      if (mounted) setState(() => _addingNote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(therapistClinicalNotesProvider(widget.patientId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Tanı', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _diagnosis,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Danışan tanısı (yalnızca koç görür)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: _savingDiagnosis ? null : _saveDiagnosis,
          child: Text(_savingDiagnosis ? 'Kaydediliyor...' : 'Tanıyı kaydet'),
        ),
        const Divider(height: 32),
        Text('Klinik notlar', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Yeni not',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _addingNote ? null : _addNote,
          child: Text(_addingNote ? 'Ekleniyor...' : 'Not ekle'),
        ),
        const SizedBox(height: 20),
        notesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Notlar alınamadı: $e'),
          data: (notes) {
            if (notes.isEmpty) return const Text('Henüz klinik not yok.');
            return Column(
              children: notes.map((n) {
                final when = n.createdAt == null ? '' : DateFormat('dd.MM.yyyy HH:mm').format(n.createdAt!);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(n.text),
                    subtitle: when.isEmpty ? null : Text(when),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => deleteTherapistClinicalNote(
                        patientId: widget.patientId,
                        noteId: n.id,
                      ),
                    ),
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
