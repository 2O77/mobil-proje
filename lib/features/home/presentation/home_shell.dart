import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sos_background_service.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/sos_alert_provider.dart';
import '../../behavior/presentation/daily_log_screen.dart';
import '../../calendar/presentation/calendar_hub_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../sos/presentation/sos_screen.dart';
import '../../therapist/presentation/therapist_patients_screen.dart';
import '../../therapist/presentation/therapist_hub_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionStreamProvider);
    return sessionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (session) {
        if (session?.profile?.role == AppUserRole.therapist) {
          return const TherapistHomeShell();
        }
        return const _PrimaryHomeShell();
      },
    );
  }
}

class _PrimaryHomeShell extends StatefulWidget {
  const _PrimaryHomeShell();

  @override
  State<_PrimaryHomeShell> createState() => _PrimaryHomeShellState();
}

class _PrimaryHomeShellState extends State<_PrimaryHomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DailyLogScreen(),
      const CalendarHubScreen(),
      const TherapistHubScreen(),
      const SosScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'Günlük'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Takvim'),
          NavigationDestination(icon: Icon(Icons.medical_services_outlined), selectedIcon: Icon(Icons.medical_services), label: 'Terapist'),
          NavigationDestination(icon: Icon(Icons.sos_outlined), selectedIcon: Icon(Icons.sos), label: 'SOS'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ayarlar'),
        ],
      ),
    );
  }
}

class TherapistHomeShell extends ConsumerStatefulWidget {
  const TherapistHomeShell({super.key});

  @override
  ConsumerState<TherapistHomeShell> createState() => _TherapistHomeShellState();
}

class _TherapistHomeShellState extends ConsumerState<TherapistHomeShell> {
  @override
  void initState() {
    super.initState();
    _startSosWatch();
    _syncFcmToken();
  }

  Future<void> _startSosWatch() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await NotificationService.ensureSosPermissions();
      await SosBackgroundService.startForTherapist(uid);
    } catch (_) {}
  }

  Future<void> _syncFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(therapistHomeTabProvider);
    final pages = const <Widget>[
      TherapistPatientsScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: index.clamp(0, pages.length - 1), children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index.clamp(0, 1),
        onDestinationSelected: (i) => ref.read(therapistHomeTabProvider.notifier).select(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Danışanlar'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ayarlar'),
        ],
      ),
    );
  }
}
