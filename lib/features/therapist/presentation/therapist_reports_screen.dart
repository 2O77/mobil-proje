import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/subject_provider.dart';

class TherapistReportsScreen extends ConsumerWidget {
  const TherapistReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(effectiveSubjectIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Raporlar')),
      body: subject == null
          ? const Center(child: CircularProgressIndicator())
          : _ReportsBody(subjectId: subject),
    );
  }
}

class _ReportsBody extends StatelessWidget {
  const _ReportsBody({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    final sessionReportsQuery = FirebaseFirestore.instance
        .collection('session_reports')
        .where('subjectUserId', isEqualTo: subjectId)
        .orderBy('createdAt', descending: true)
        .limit(50);

    final assessmentsQuery = FirebaseFirestore.instance
        .collection('assessments')
        .where('subjectUserId', isEqualTo: subjectId)
        .orderBy('createdAt', descending: true)
        .limit(50);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Seçili danışan: $subjectId', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        const Text('Seans raporları', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: sessionReportsQuery.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Seans raporları alınamadı: ${snap.error}'),
              );
            }
            if (!snap.hasData) return const LinearProgressIndicator();
            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Seans raporu yok.'));
            return Column(
              children: docs.map((d) {
                final data = d.data();
                final title = (data['title'] as String?) ?? 'Rapor';
                final body = (data['body'] as String?) ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(title),
                    subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
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
            if (snap.hasError) {
              return Text('Değerlendirmeler alınamadı: ${snap.error}');
            }
            if (!snap.hasData) return const LinearProgressIndicator();
            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Text('Değerlendirme yok.');
            return Column(
              children: docs.map((d) {
                final data = d.data();
                final type = (data['type'] as String?) ?? 'assessment';
                final answers = (data['answers'] as Map<String, dynamic>?) ?? const {};
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(type),
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
