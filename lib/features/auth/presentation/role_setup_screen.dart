import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';

class RoleSetupScreen extends StatefulWidget {
  const RoleSetupScreen({super.key});

  @override
  State<RoleSetupScreen> createState() => _RoleSetupScreenState();
}

class _RoleSetupScreenState extends State<RoleSetupScreen> {
  AppUserRole? _picked;
  var _loading = false;
  String? _error;

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _picked == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'role': _picked!.wire},
        SetOptions(merge: true),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rol seçimi')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'AutiCare içinde nasıl devam edeceksiniz?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          RadioListTile<AppUserRole>(
            title: const Text('Birey (OSB)'),
            value: AppUserRole.individual,
            groupValue: _picked,
            onChanged: (v) => setState(() => _picked = v),
          ),
          RadioListTile<AppUserRole>(
            title: const Text('Ebeveyn / bakım veren'),
            value: AppUserRole.caregiver,
            groupValue: _picked,
            onChanged: (v) => setState(() => _picked = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_loading || _picked == null) ? null : _save,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Devam et'),
          ),
        ],
      ),
    );
  }
}
