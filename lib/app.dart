import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/services/medication_reminder_init.dart';
import 'core/theme/app_theme.dart';

class AutiCareApp extends ConsumerWidget {
  const AutiCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(fcmInitProvider);
    ref.watch(medicationRemindersInitProvider);
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'AutiCare',
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
