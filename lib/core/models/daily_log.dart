import 'package:cloud_firestore/cloud_firestore.dart';

class DailyLog {
  DailyLog({
    required this.id,
    required this.userId,
    required this.dateKey,
    this.moodEmoji,
    this.sleepHours,
    this.mealLevel,
    this.waterGlasses,
    this.stress1to10,
    this.note,
    this.voiceUrl,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String dateKey;
  final String? moodEmoji;
  final double? sleepHours;
  final int? mealLevel;
  final int? waterGlasses;
  final int? stress1to10;
  final String? note;
  final String? voiceUrl;
  final DateTime createdAt;

  factory DailyLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final ts = d['createdAt'];
    return DailyLog(
      id: doc.id,
      userId: d['userId'] as String,
      dateKey: d['dateKey'] as String,
      moodEmoji: d['moodEmoji'] as String?,
      sleepHours: (d['sleepHours'] as num?)?.toDouble(),
      mealLevel: (d['mealLevel'] as num?)?.toInt(),
      waterGlasses: (d['waterGlasses'] as num?)?.toInt(),
      stress1to10: (d['stress1to10'] as num?)?.toInt(),
      note: d['note'] as String?,
      voiceUrl: d['voiceUrl'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toCreate() => {
        'userId': userId,
        'dateKey': dateKey,
        if (moodEmoji != null) 'moodEmoji': moodEmoji,
        if (sleepHours != null) 'sleepHours': sleepHours,
        if (mealLevel != null) 'mealLevel': mealLevel,
        if (waterGlasses != null) 'waterGlasses': waterGlasses,
        if (stress1to10 != null) 'stress1to10': stress1to10,
        if (note != null) 'note': note,
        if (voiceUrl != null) 'voiceUrl': voiceUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toFirestoreFullWrite({required bool updating}) => {
        'userId': userId,
        'dateKey': dateKey,
        'moodEmoji': moodEmoji,
        'sleepHours': sleepHours,
        'mealLevel': mealLevel,
        'waterGlasses': waterGlasses,
        'stress1to10': stress1to10,
        'note': note,
        'voiceUrl': voiceUrl,
        'createdAt': updating ? Timestamp.fromDate(createdAt) : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

