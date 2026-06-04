import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/patient_profile_provider.dart';
import '../../../core/providers/subject_provider.dart';
import '../../../core/services/sos_location_service.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  List<String> _guideSteps = [];
  final _preset = TextEditingController();
  List<String> _presets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/crisis_guide.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final steps = List<String>.from(map['steps'] as List? ?? const []);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('sos_presets') ?? ['Yardıma ihtiyacım var', 'Lütfen beni ara'];
    setState(() {
      _guideSteps = steps;
      _presets = saved;
    });
  }

  @override
  void dispose() {
    _preset.dispose();
    super.dispose();
  }

  Future<void> _savePreset() async {
    final t = _preset.text.trim();
    if (t.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _presets = [..._presets, t];
    await prefs.setStringList('sos_presets', _presets);
    _preset.clear();
    setState(() {});
  }

  Future<void> _sendSos() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;
    final subjectId = ref.read(effectiveSubjectIdProvider) ?? me;
    final therapistId = ref.read(patientProfileProvider(subjectId)).value?.linkedTherapistId;

    final location = await SosLocationCapture.capture();
    final pos = location.position;

    final payload = <String, dynamic>{
      'userId': subjectId,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (pos != null) {
      payload['lat'] = pos.latitude;
      payload['lng'] = pos.longitude;
      payload['locationAccuracy'] = pos.accuracy;
    }
    if (therapistId != null && therapistId.isNotEmpty) {
      payload['therapistId'] = therapistId;
    }

    await FirebaseFirestore.instance.collection('sos_events').add(payload);
    if (!mounted) return;

    final locText = pos == null ? (location.message ?? 'Konum gönderilemedi') : formatSosCoordinates(pos.latitude, pos.longitude);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SOS gönderildi. Konum: $locText')),
    );
  }

  Future<void> _sms(String body) async {
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(body)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS ve acil durum')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.errorContainer),
            onPressed: _sendSos,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('TEK DOKUNUŞ SOS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'SOS ile birlikte güncel konumunuz koça iletilir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const Text('Önceden tanımlı mesajlar', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._presets.map(
            (p) => ListTile(
              title: Text(p),
              trailing: IconButton(icon: const Icon(Icons.sms_outlined), onPressed: () => _sms(p)),
            ),
          ),
          TextField(controller: _preset, decoration: const InputDecoration(labelText: 'Yeni acil mesaj')),
          TextButton(onPressed: _savePreset, child: const Text('Mesajı kaydet')),
          const Divider(height: 32),
          const Text('Kriz protokolü (çevrimdışı özet)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._guideSteps.map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('• $s'))),
        ],
      ),
    );
  }
}
