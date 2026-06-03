import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.hour,
    required this.minute,
    this.enabled = true,
  });

  final String id;
  final String userId;
  final String name;
  final int hour;
  final int minute;
  final bool enabled;

  factory Medication.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Medication(
      id: doc.id,
      userId: d['userId'] as String,
      name: d['name'] as String,
      hour: (d['hour'] as num).toInt(),
      minute: (d['minute'] as num).toInt(),
      enabled: d['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
