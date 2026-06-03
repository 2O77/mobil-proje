import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/daily_log.dart';
import '../../../core/providers/subject_provider.dart';
import '../providers/today_daily_log_provider.dart';

class DailyLogScreen extends ConsumerStatefulWidget {
  const DailyLogScreen({super.key});

  @override
  ConsumerState<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends ConsumerState<DailyLogScreen> {
  final _note = TextEditingController();
  final _sleep = TextEditingController();
  final _meal = TextEditingController();
  final _water = TextEditingController();
  String? _mood;
  double _stress = 5;
  var _saving = false;
  String? _status;
  String? _lastFormSyncKey;
  String? _pendingCreatedDocId;

  static const _moods = ['😊', '🙂', '😐', '😟', '😣'];

  @override
  void initState() {
    super.initState();
    ref.listenManual<String?>(
      effectiveSubjectIdProvider,
      (prev, next) {
        if (prev == next) return;
        _lastFormSyncKey = null;
        _pendingCreatedDocId = null;
        ref.invalidate(todayDailyLogStreamProvider);
        if (next == null && mounted) {
          _clearForm();
          setState(() => _status = null);
        }
      },
      fireImmediately: true,
    );
    ref.listenManual<AsyncValue<DailyLog?>>(
      todayDailyLogStreamProvider,
      (prev, next) {
        if (!mounted) return;
        switch (next) {
          case AsyncData(:final value):
            final sub = ref.read(effectiveSubjectIdProvider);
            if (sub == null) return;
            final dk = DateFormat('yyyy-MM-dd').format(DateTime.now());
            _syncFormFromStream(value, sub, dk);
          default:
            break;
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _note.dispose();
    _sleep.dispose();
    _meal.dispose();
    _water.dispose();
    super.dispose();
  }

  void _clearForm() {
    _note.clear();
    _sleep.clear();
    _meal.clear();
    _water.clear();
    setState(() {
      _mood = null;
      _stress = 5;
    });
  }

  void _applyLogToForm(DailyLog log) {
    _sleep.text = log.sleepHours != null ? _formatNum(log.sleepHours!) : '';
    _meal.text = log.mealLevel?.toString() ?? '';
    _water.text = log.waterGlasses?.toString() ?? '';
    _note.text = log.note ?? '';
    setState(() {
      _mood = log.moodEmoji;
      _stress = (log.stress1to10 ?? 5).toDouble();
    });
  }

  String _formatNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  void _syncFormFromStream(DailyLog? log, String subject, String dateKey) {
    final syncKey = '${subject}_${dateKey}_${log?.id ?? 'none'}';
    if (_lastFormSyncKey == syncKey) return;
    _lastFormSyncKey = syncKey;
    if (log == null) {
      _pendingCreatedDocId = null;
      _clearForm();
      return;
    }
    if (_pendingCreatedDocId != null && log.id == _pendingCreatedDocId) {
      _pendingCreatedDocId = null;
    }
    _applyLogToForm(log);
  }

  Future<void> _save() async {
    final subjectId = ref.read(effectiveSubjectIdProvider);
    if (subjectId == null) return;
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final streamLog = ref.read(todayDailyLogStreamProvider).when(
            data: (v) => v,
            loading: () => null,
            error: (_, __) => null,
          );
      final existingId = streamLog?.id ?? _pendingCreatedDocId;
      final updating = existingId != null;
      final id = existingId ?? FirebaseFirestore.instance.collection('daily_logs').doc().id;
      final log = DailyLog(
        id: id,
        userId: subjectId,
        dateKey: dateKey,
        moodEmoji: _mood,
        sleepHours: double.tryParse(_sleep.text.replaceAll(',', '.')),
        mealLevel: int.tryParse(_meal.text),
        waterGlasses: int.tryParse(_water.text),
        stress1to10: _stress.round(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        voiceUrl: streamLog?.voiceUrl,
        createdAt: streamLog?.createdAt ?? DateTime.now(),
      );
      await FirebaseFirestore.instance.collection('daily_logs').doc(id).set(log.toFirestoreFullWrite(updating: updating));
      if (!updating) {
        _pendingCreatedDocId = id;
      }
      if (mounted) {
        setState(() => _status = 'Kaydedildi');
      }
    } catch (e) {
      if (mounted) setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(effectiveSubjectIdProvider);
    final todayAsync = ref.watch(todayDailyLogStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Günlük davranış')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          if (subject != null)
            Text('Kayıt hedefi: $subject', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          todayAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 3),
            error: (e, _) => Text('Yükleme: $e'),
            data: (log) {
              if (log != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Bugün için günlük gönderdiniz. İsterseniz aşağıdan düzenleyip tekrar kaydedebilirsiniz.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const Text('Duygu durumu'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _moods
                .map(
                  (e) => ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 28)),
                    selected: _mood == e,
                    onSelected: (_) => setState(() => _mood = e),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _sleep,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Uyku (saat)'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _meal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Yemek (1-5 tahmini)'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _water,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Su (bardak)'),
          ),
          const SizedBox(height: 16),
          Text('Stres: ${_stress.round()} / 10'),
          Slider(
            value: _stress,
            min: 1,
            max: 10,
            divisions: 9,
            label: '${_stress.round()}',
            onChanged: (v) => setState(() => _stress = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Serbest not'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 14),
            Text(_status!),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _saving || subject == null ? null : _save,
            child: _saving ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
