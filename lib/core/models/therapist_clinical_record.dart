import 'package:cloud_firestore/cloud_firestore.dart';

class TherapistClinicalRecord {
  const TherapistClinicalRecord({
    required this.patientId,
    required this.therapistId,
    this.diagnosis = '',
    this.updatedAt,
  });

  final String patientId;
  final String therapistId;
  final String diagnosis;
  final DateTime? updatedAt;

  factory TherapistClinicalRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final updatedAt = data['updatedAt'];
    return TherapistClinicalRecord(
      patientId: data['patientId'] as String? ?? doc.id,
      therapistId: data['therapistId'] as String? ?? '',
      diagnosis: data['diagnosis'] as String? ?? '',
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }
}

class TherapistClinicalNote {
  const TherapistClinicalNote({
    required this.id,
    required this.text,
    required this.authorId,
    this.createdAt,
  });

  final String id;
  final String text;
  final String authorId;
  final DateTime? createdAt;

  factory TherapistClinicalNote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final createdAt = data['createdAt'];
    return TherapistClinicalNote(
      id: doc.id,
      text: data['text'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}
