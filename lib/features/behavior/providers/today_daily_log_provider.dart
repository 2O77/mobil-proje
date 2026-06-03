import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/daily_log.dart';
import '../../../core/providers/subject_provider.dart';

final todayDailyLogStreamProvider = StreamProvider.autoDispose<DailyLog?>((ref) {
  final subject = ref.watch(effectiveSubjectIdProvider);
  if (subject == null) {
    return Stream.value(null);
  }
  final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return FirebaseFirestore.instance
      .collection('daily_logs')
      .where('userId', isEqualTo: subject)
      .where('dateKey', isEqualTo: dateKey)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : DailyLog.fromDoc(s.docs.first));
});
