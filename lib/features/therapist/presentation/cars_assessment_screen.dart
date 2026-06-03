import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/subject_provider.dart';

class CarsAssessmentScreen extends ConsumerStatefulWidget {
  const CarsAssessmentScreen({super.key});

  @override
  ConsumerState<CarsAssessmentScreen> createState() => _CarsAssessmentScreenState();
}

class _CarsAssessmentScreenState extends ConsumerState<CarsAssessmentScreen> {
  static const _items = <Map<String, dynamic>>[
    {'q': 'Sosyal tepkilerde göz teması ve ortak dikkat davranışları gözlemleniyor mu?', 'k': 'q1'},
    {'q': 'Tekrarlayıcı davranışlar veya sınırlı ilgi alanları var mı?', 'k': 'q2'},
    {'q': 'Duyusal uyaranlara aşırı veya yetersiz tepki görülüyor mu?', 'k': 'q3'},
    {'q': 'Dil ve iletişim yaşına uygun mu?', 'k': 'q4'},
  ];

  final Map<String, int> _answers = {};

  Future<void> _save() async {
    final subject = ref.read(effectiveSubjectIdProvider);
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (subject == null || me == null) return;
    await FirebaseFirestore.instance.collection('assessments').add({
      'subjectUserId': subject,
      'authorId': me,
      'type': 'cars2_placeholder',
      'answers': _answers.map((k, v) => MapEntry(k, v)),
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anket kaydedildi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CARS-2 uyumlu örnek anket')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Bu maddeler örnektir; tam CARS-2 lisanslı içerik değildir. Klinik karar için uzman değerlendirmesi gereklidir.',
                style: TextStyle(fontSize: 13),
              ),
            );
          }
          if (i == _items.length + 1) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton(onPressed: _save, child: const Text('Kaydet')),
            );
          }
          final item = _items[i - 1];
          final key = item['k'] as String;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['q'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('0')),
                      ButtonSegment(value: 1, label: Text('1')),
                      ButtonSegment(value: 2, label: Text('2')),
                      ButtonSegment(value: 3, label: Text('3')),
                    ],
                    selected: {_answers[key] ?? 1},
                    onSelectionChanged: (s) => setState(() => _answers[key] = s.first),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
