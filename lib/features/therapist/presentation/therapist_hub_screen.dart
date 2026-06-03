import 'package:flutter/material.dart';

import 'cars_assessment_screen.dart';
import 'messages_screen.dart';
import 'session_pdf_screen.dart';

class TherapistHubScreen extends StatelessWidget {
  const TherapistHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terapist bağlantısı')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _tile(
            context,
            icon: Icons.chat_bubble_outline,
            title: 'Güvenli mesajlaşma',
            subtitle: 'Firestore üzerinden gerçek zamanlı',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MessagesScreen())),
          ),
          _tile(
            context,
            icon: Icons.picture_as_pdf_outlined,
            title: 'Seans notu PDF',
            subtitle: 'Dışa aktarma ve paylaşım',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SessionPdfScreen())),
          ),
          _tile(
            context,
            icon: Icons.assignment_outlined,
            title: 'CARS-2 uyumlu anket',
            subtitle: 'Örnek maddeler (telifli tam ölçek değildir)',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CarsAssessmentScreen())),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
