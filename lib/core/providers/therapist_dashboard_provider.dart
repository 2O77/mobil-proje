import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/conversation_service.dart';
import 'subject_provider.dart';

class TherapistConversationPreview {
  const TherapistConversationPreview({
    required this.conversationId,
    required this.patientId,
    this.lastMessageText,
    this.updatedAt,
  });

  final String conversationId;
  final String patientId;
  final String? lastMessageText;
  final DateTime? updatedAt;
}

final therapistConversationsProvider = StreamProvider<List<TherapistConversationPreview>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);

  final patientIds = ref.watch(therapistPatientsProvider).value ?? const [];
  if (patientIds.isNotEmpty) {
    ensureTherapistPatientConversations(therapistId: uid, patientIds: patientIds);
  }

  return FirebaseFirestore.instance
      .collection('conversations')
      .where('participantIds', arrayContains: uid)
      .snapshots()
      .map((snap) {
    final byPatient = <String, TherapistConversationPreview>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participantIds'] as List? ?? const []);
      final patientId = participants.firstWhere((id) => id != uid, orElse: () => '');
      if (patientId.isEmpty) continue;
      final updatedAt = data['updatedAt'];
      byPatient[patientId] = TherapistConversationPreview(
        conversationId: doc.id,
        patientId: patientId,
        lastMessageText: data['lastMessageText'] as String?,
        updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
      );
    }
    if (patientIds.isEmpty) {
      return byPatient.values.toList()
        ..sort((a, b) {
          final aTime = a.updatedAt;
          final bTime = b.updatedAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
    }
    final items = patientIds.map((patientId) {
      return byPatient[patientId] ??
          TherapistConversationPreview(
            conversationId: conversationIdFor(uid, patientId),
            patientId: patientId,
          );
    }).toList();
    items.sort((a, b) {
      final aTime = a.updatedAt;
      final bTime = b.updatedAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return items;
  });
});
