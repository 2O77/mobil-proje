import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/subject_provider.dart';
import '../../../core/services/session_report_pdf_service.dart';
import 'session_report_card.dart';

class SessionPdfScreen extends ConsumerStatefulWidget {
  const SessionPdfScreen({super.key});

  @override
  ConsumerState<SessionPdfScreen> createState() => _SessionPdfScreenState();
}

class _SessionPdfScreenState extends ConsumerState<SessionPdfScreen> {
  final _title = TextEditingController(text: 'Seans özeti');
  final _body = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _saveAndExport() async {
    if (_saving) return;
    final me = FirebaseAuth.instance.currentUser?.uid;
    final subject = ref.read(effectiveSubjectIdProvider);
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (me == null || subject == null || title.isEmpty || body.isEmpty) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('session_reports').add({
        'subjectUserId': subject,
        'authorId': me,
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await openSessionReportPdf(title: title, body: body, sessionDate: DateTime.now());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(effectiveSubjectIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Seans raporları')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Başlık')),
          const SizedBox(height: 12),
          TextField(controller: _body, maxLines: 10, decoration: const InputDecoration(labelText: 'Not metni')),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _saveAndExport,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_alt_outlined),
            label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet ve PDF indir'),
          ),
          const Divider(height: 32),
          const Text('Kayıtlı raporlar', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (subject == null)
            const Text('Raporları görmek için oturum açın.')
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('session_reports')
                  .where('subjectUserId', isEqualTo: subject)
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text('Raporlar alınamadı: ${snap.error}');
                }
                if (!snap.hasData) return const LinearProgressIndicator();
                final docs = snap.data!.docs;
                if (docs.isEmpty) return const Text('Henüz kayıtlı rapor yok.');
                return Column(
                  children: docs.map((d) => SessionReportCard.fromDoc(d)).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}
