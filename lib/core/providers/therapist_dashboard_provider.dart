import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


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

  return FirebaseFirestore.instance
      .collection('conversations')
      .where('participantIds', arrayContains: uid)
      .orderBy('updatedAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) {
    return snap.docs.map((doc) {
      final data = doc.data();
      final participants = List<String>.from(data['participantIds'] as List? ?? const []);
      final patientId = participants.firstWhere((id) => id != uid, orElse: () => '');
      final updatedAt = data['updatedAt'];
      return TherapistConversationPreview(
        conversationId: doc.id,
        patientId: patientId,
        lastMessageText: data['lastMessageText'] as String?,
        updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
      );
    }).where((c) => c.patientId.isNotEmpty).toList();
  });
});

String conversationIdFor(String a, String b) {
  final list = [a, b]..sort();
  return '${list[0]}__${list[1]}';
}
