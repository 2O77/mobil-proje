import 'package:cloud_firestore/cloud_firestore.dart';

class SosEvent {
  const SosEvent({
    required this.id,
    required this.userId,
    this.therapistId,
    this.status = 'active',
    this.createdAt,
    this.lat,
    this.lng,
    this.acknowledgedAt,
    this.acknowledgedBy,
  });

  final String id;
  final String userId;
  final String? therapistId;
  final String status;
  final DateTime? createdAt;
  final double? lat;
  final double? lng;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;

  bool get isActive => status == 'active';

  factory SosEvent.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    final acknowledgedAt = data['acknowledgedAt'];
    return SosEvent(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      therapistId: data['therapistId'] as String?,
      status: data['status'] as String? ?? 'active',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      acknowledgedAt: acknowledgedAt is Timestamp ? acknowledgedAt.toDate() : null,
      acknowledgedBy: data['acknowledgedBy'] as String?,
    );
  }
}
