// Owns the root Material app, global theme, routing, and notification links.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import '../core/services/notification_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class MentoApp extends ConsumerStatefulWidget {
  const MentoApp({super.key});

  @override
  ConsumerState<MentoApp> createState() => _MentoAppState();
}

class _MentoAppState extends ConsumerState<MentoApp> {
  StreamSubscription<String>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notificationSubscription = NotificationService.instance.payloads.listen((
      location,
    ) {
      if (location.startsWith('/')) {
        ref.read(appRouterProvider).go(location);
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final reduceMotion =
        ref.watch(sharedPreferencesProvider).getBool('mento.reduced_motion') ??
        false;
    return MaterialApp.router(
      title: 'Mento',
      debugShowCheckedModeBanner: false,
      theme: MentoTheme.light,
      darkTheme: MentoTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 240),
      routerConfig: router,
    );
  }
}
