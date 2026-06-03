import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationTime {
  const MedicationTime({required this.hour, required this.minute});

  final int hour;
  final int minute;

  factory MedicationTime.fromMap(Map<String, dynamic> data) {
    return MedicationTime(
      hour: (data['hour'] as num).toInt(),
      minute: (data['minute'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {'hour': hour, 'minute': minute};

  String get label {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class Medication {
  Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.times,
    this.enabled = true,
  });

  final String id;
  final String userId;
  final String name;
  final List<MedicationTime> times;
  final bool enabled;

  factory Medication.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final rawTimes = d['times'] as List?;
    final times = rawTimes == null
        ? <MedicationTime>[]
        : rawTimes
            .whereType<Map>()
            .map((e) => MedicationTime.fromMap(Map<String, dynamic>.from(e)))
            .toList();
    if (times.isEmpty && d['hour'] != null) {
      times.add(
        MedicationTime(
          hour: (d['hour'] as num).toInt(),
          minute: (d['minute'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return Medication(
      id: doc.id,
      userId: d['userId'] as String,
      name: d['name'] as String,
      times: times,
      enabled: d['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'times': times.map((t) => t.toMap()).toList(),
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  String get timesLabel => times.map((t) => t.label).join(', ');
}
