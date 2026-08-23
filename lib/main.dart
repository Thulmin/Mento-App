// Starts Mento after its local and cloud services have been prepared.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/theme/theme_controller.dart';

Future<void> main() async {
  // Bootstrap before runApp so every provider sees the same startup result.
  final bootstrap = await bootstrapMento();
  runApp(
    ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(bootstrap),
        sharedPreferencesProvider.overrideWithValue(bootstrap.preferences),
      ],
      child: const MentoApp(),
    ),
  );
}
