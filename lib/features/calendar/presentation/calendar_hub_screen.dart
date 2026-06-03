import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/medication.dart';
import '../../../core/models/routine.dart';
import '../../../core/providers/subject_provider.dart';
import '../../../core/services/medication_notification_service.dart';
import '../../../core/services/medication_reminder_init.dart';
import '../../../core/services/notification_service.dart';

class CalendarHubScreen extends ConsumerStatefulWidget {
  const CalendarHubScreen({super.key});

  @override
  ConsumerState<CalendarHubScreen> createState() => _CalendarHubScreenState();
}

class _CalendarHubScreenState extends ConsumerState<CalendarHubScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Takvim ve rutin'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Görevler'),
            Tab(text: 'İlaçlar'),
            Tab(text: 'Zamanlayıcı'),
            Tab(text: 'Haftalık'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _RoutinesTab(),
          _MedicationsTab(),
          _TimerTab(),
          _WeeklyTab(),
        ],
      ),
    );
  }
}

class _RoutinesTab extends ConsumerWidget {
  const _RoutinesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(effectiveSubjectIdProvider);
    if (subject == null) return const Center(child: Text('Oturum yok'));
    final q = FirebaseFirestore.instance.collection('routines').where('userId', isEqualTo: subject);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _addRoutine(context, ref, subject),
            icon: const Icon(Icons.add),
            label: const Text('Görev ekle'),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('Henüz görev yok'));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final t = RoutineTask.fromDoc(docs[i]);
                  return CheckboxListTile(
                    title: Text(t.title),
                    subtitle: Text(
                      t.scheduledHour != null ? '${t.scheduledHour}:${(t.scheduledMinute ?? 0).toString().padLeft(2, '0')}' : 'Saat yok',
                    ),
                    value: t.done,
                    onChanged: (v) => docs[i].reference.update({'done': v ?? false}),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  static Future<void> _addRoutine(BuildContext context, WidgetRef ref, String subject) async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni görev'),
        content: TextField(controller: title, decoration: const InputDecoration(labelText: 'Başlık')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('routines').add({
        'userId': subject,
        'title': title.text.trim(),
        'done': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

class _MedicationsTab extends ConsumerStatefulWidget {
  const _MedicationsTab();

  @override
  ConsumerState<_MedicationsTab> createState() => _MedicationsTabState();
}

class _MedicationsTabState extends ConsumerState<_MedicationsTab> {
  String? _lastSyncKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.ensureMedicationPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(effectiveSubjectIdProvider);
    if (subject == null) return const Center(child: Text('Oturum yok'));
    final q = FirebaseFirestore.instance.collection('medications').where('userId', isEqualTo: subject);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _addMed(context, subject),
            icon: const Icon(Icons.add),
            label: const Text('İlaç ekle'),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final meds = snap.data!.docs.map(Medication.fromDoc).toList();
              final syncKey = '$subject:${meds.map((m) => '${m.id}:${m.timesLabel}').join('|')}';
              if (_lastSyncKey != syncKey) {
                _lastSyncKey = syncKey;
                MedicationNotificationService.syncAll(meds);
              }
              if (meds.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Henüz ilaç yok.\nSaatleriyle birlikte ekleyin; bildirim alırsınız.'),
                  ),
                );
              }
              return ListView.builder(
                itemCount: meds.length,
                itemBuilder: (_, i) {
                  final med = meds[i];
                  return ListTile(
                    title: Text(med.name),
                    subtitle: Text(
                      med.times.isEmpty ? 'Saat tanımlı değil' : 'Saatler: ${med.timesLabel}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await MedicationNotificationService.cancel(med.id, med.times.length + 8);
                        await snap.data!.docs[i].reference.delete();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addMed(BuildContext context, String subject) async {
    final name = TextEditingController();
    final times = <MedicationTime>[];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('İlaç ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'İlaç adı'),
                  onChanged: (_) => setS(() {}),
                ),
                const SizedBox(height: 12),
                const Text('Alınacak saatler', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (times.isEmpty)
                  const Text('En az bir saat ekleyin.', style: TextStyle(fontSize: 13))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < times.length; i++)
                        InputChip(
                          label: Text(times[i].label),
                          onDeleted: () => setS(() => times.removeAt(i)),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                    if (t == null) return;
                    final duplicate = times.any((e) => e.hour == t.hour && e.minute == t.minute);
                    if (duplicate) return;
                    setS(() => times.add(MedicationTime(hour: t.hour, minute: t.minute)));
                  },
                  icon: const Icon(Icons.schedule),
                  label: const Text('Saat ekle'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            FilledButton(
              onPressed: name.text.trim().isEmpty || times.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty || times.isEmpty) return;

    times.sort((a, b) {
      final ah = a.hour * 60 + a.minute;
      final bh = b.hour * 60 + b.minute;
      return ah.compareTo(bh);
    });

    final doc = await FirebaseFirestore.instance.collection('medications').add({
      'userId': subject,
      'name': name.text.trim(),
      'times': times.map((t) => t.toMap()).toList(),
      'enabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final med = Medication(
      id: doc.id,
      userId: subject,
      name: name.text.trim(),
      times: times,
    );
    final scheduled = await scheduleMedicationReminders(med);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          scheduled
              ? '${med.name} için ${times.length} hatırlatıcı ayarlandı'
              : 'İlaç kaydedildi ama bildirim izni yok. Ayarlardan bildirim ve alarm iznini açın.',
        ),
      ),
    );
  }
}

class _TimerTab extends StatefulWidget {
  const _TimerTab();

  @override
  State<_TimerTab> createState() => _TimerTabState();
}

class _TimerTabState extends State<_TimerTab> {
  int _secondsLeft = 0;
  int _pickedMinutes = 5;
  bool _running = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = _pickedMinutes * 60;
      _running = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft <= 1) {
          _secondsLeft = 0;
          _running = false;
          _timer?.cancel();
        } else {
          _secondsLeft--;
        }
      });
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _secondsLeft = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('Görsel zamanlayıcı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            width: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: _secondsLeft == 0 && !_running ? 0 : 1 - (_secondsLeft / (_pickedMinutes * 60).clamp(1, 999999)),
                  strokeWidth: 10,
                ),
                Center(
                  child: Text(
                    '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [3, 5, 10, 15]
                .map(
                  (m) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('$m dk'),
                      selected: _pickedMinutes == m,
                      onSelected: (_) => setState(() => _pickedMinutes = m),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                onPressed: _running
                    ? null
                    : _start,
                child: const Text('Başlat'),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: _reset,
                child: const Text('Sıfırla'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyTab extends ConsumerWidget {
  const _WeeklyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(effectiveSubjectIdProvider);
    if (subject == null) return const Center(child: Text('Oturum yok'));
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final q = FirebaseFirestore.instance.collection('daily_logs').where('userId', isEqualTo: subject).limit(200);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var n = 0;
        for (final d in snap.data!.docs) {
          final key = d.data()['dateKey'] as String?;
          if (key == null) continue;
          final parts = key.split('-');
          if (parts.length != 3) continue;
          final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          if (!dt.isBefore(cutoff)) n++;
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Son 7 gün', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('Kayıtlı günlük girişi: $n'),
              const SizedBox(height: 8),
              const Text('Daha ayrıntılı grafikler için veriler Firestore üzerinden genişletilebilir.'),
            ],
          ),
        );
      },
    );
  }
}
