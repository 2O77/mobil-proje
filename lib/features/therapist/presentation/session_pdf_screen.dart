import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/subject_provider.dart';
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

  Future<void> _saveAndExport(String subjectUserId) async {
    if (_saving) return;
    final me = FirebaseAuth.instance.currentUser?.uid;
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (me == null || title.isEmpty || body.isEmpty) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('session_reports').add({
        'subjectUserId': subjectUserId,
        'authorId': me,
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _body.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapor gönderildi')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gönderilemedi: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortReports(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return [...docs]..sort((a, b) {
        final aTs = a.data()['createdAt'];
        final bTs = b.data()['createdAt'];
        if (aTs is! Timestamp && bTs is! Timestamp) return 0;
        if (aTs is! Timestamp) return 1;
        if (bTs is! Timestamp) return -1;
        return bTs.compareTo(aTs);
      });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final subjectUserId = ref.watch(effectiveSubjectIdProvider) ?? uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Seans raporları')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (uid != null) ...[
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Başlık')),
            const SizedBox(height: 12),
            TextField(controller: _body, maxLines: 10, decoration: const InputDecoration(labelText: 'Not metni')),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving || subjectUserId == null ? null : () => _saveAndExport(subjectUserId),
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: Text(_saving ? 'Gönderiliyor...' : 'Gönder'),
            ),
            const Divider(height: 32),
          ],
          const Text('Kayıtlı raporlar', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (uid == null)
            const Text('Raporları görmek için oturum açın.')
          else if (subjectUserId == null)
            const LinearProgressIndicator()
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('session_reports')
                  .where('subjectUserId', isEqualTo: subjectUserId)
                  .limit(50)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text('Raporlar alınamadı: ${snap.error}');
                }
                if (!snap.hasData) return const LinearProgressIndicator();
                final docs = _sortReports(snap.data!.docs);
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
