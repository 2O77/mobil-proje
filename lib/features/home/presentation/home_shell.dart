import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/sos_alert_provider.dart';
import '../../behavior/presentation/daily_log_screen.dart';
import '../../calendar/presentation/calendar_hub_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../sos/presentation/sos_screen.dart';
import '../../therapist/presentation/messages_screen.dart';
import '../../therapist/presentation/therapist_patients_screen.dart';
import '../../therapist/presentation/therapist_reports_screen.dart';
import '../../therapist/presentation/therapist_sos_alert_widgets.dart';
import '../../therapist/presentation/therapist_sos_screen.dart';
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
      const ProfileScreen(),
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
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
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
    _syncFcmToken();
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
    final activeCount = ref.watch(therapistActiveSosProvider).maybeWhen(data: (d) => d.length, orElse: () => 0);
    final pages = <Widget>[
      const TherapistPatientsScreen(),
      const MessagesScreen(),
      const TherapistSosScreen(),
      const TherapistReportsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: Column(
        children: [
          const TherapistSosAlertBanner(),
          Expanded(child: IndexedStack(index: index, children: pages)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(therapistHomeTabProvider.notifier).select(i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Danışanlar'),
          const NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Mesajlar'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.sos_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.sos),
            ),
            label: 'SOS',
          ),
          const NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Raporlar'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
