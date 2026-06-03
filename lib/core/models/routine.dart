import 'package:cloud_firestore/cloud_firestore.dart';

class RoutineTask {
  RoutineTask({
    required this.id,
    required this.userId,
    required this.title,
    this.done = false,
    this.scheduledHour,
    this.scheduledMinute,
  });

  final String id;
  final String userId;
  final String title;
  final bool done;
  final int? scheduledHour;
  final int? scheduledMinute;

  factory RoutineTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return RoutineTask(
      id: doc.id,
      userId: d['userId'] as String,
      title: d['title'] as String,
      done: d['done'] as bool? ?? false,
      scheduledHour: (d['scheduledHour'] as num?)?.toInt(),
      scheduledMinute: (d['scheduledMinute'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'done': done,
        if (scheduledHour != null) 'scheduledHour': scheduledHour,
        if (scheduledMinute != null) 'scheduledMinute': scheduledMinute,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
