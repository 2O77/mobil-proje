import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/providers/subject_provider.dart';

class SessionPdfScreen extends ConsumerStatefulWidget {
  const SessionPdfScreen({super.key});

  @override
  ConsumerState<SessionPdfScreen> createState() => _SessionPdfScreenState();
}

class _SessionPdfScreenState extends ConsumerState<SessionPdfScreen> {
  final _title = TextEditingController(text: 'Seans özeti');
  final _body = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _sharePdf(String title, String body) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text(body),
          ],
        ),
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'auticare_seans.pdf');
  }

  Future<void> _saveAndExport() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final subject = ref.read(effectiveSubjectIdProvider);
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (me == null || subject == null || title.isEmpty || body.isEmpty) return;

    await FirebaseFirestore.instance.collection('session_reports').add({
      'subjectUserId': subject,
      'authorId': me,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _sharePdf(title, body);
  }

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(effectiveSubjectIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Seans notu PDF')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Başlık')),
          const SizedBox(height: 12),
          TextField(controller: _body, maxLines: 10, decoration: const InputDecoration(labelText: 'Not metni')),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saveAndExport,
            icon: const Icon(Icons.share),
            label: const Text('Kaydet, PDF oluştur ve paylaş'),
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
                if (!snap.hasData) return const LinearProgressIndicator();
                final docs = snap.data!.docs;
                if (docs.isEmpty) return const Text('Henüz kayıtlı rapor yok.');
                return Column(
                  children: docs.map((d) {
                    final data = d.data();
                    final title = (data['title'] as String?) ?? 'Rapor';
                    final body = (data['body'] as String?) ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(title),
                      subtitle: Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () => _sharePdf(title, body),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}
