// Prepares local preferences, notifications, Firebase, and optional emulators.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/services/notification_service.dart';

@immutable
class BootstrapResult {
  const BootstrapResult({
    required this.preferences,
    required this.firebaseReady,
    required this.startedAt,
    this.firebaseError,
  });

  final SharedPreferences preferences;
  final bool firebaseReady;
  final DateTime startedAt;
  final Object? firebaseError;
}

final bootstrapProvider = Provider<BootstrapResult>((ref) {
  throw StateError('BootstrapResult must be overridden in main().');
});

Future<BootstrapResult> bootstrapMento() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startedAt = DateTime.now();
  final preferences = await SharedPreferences.getInstance();
  try {
    await NotificationService.instance.initialize();
  } catch (error, stackTrace) {
    // A Firebase setup problem should not prevent the safe demo experience
    // from opening, so the error is reported and returned as startup state.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Mento notifications',
        context: ErrorDescription('initializing local notifications'),
      ),
    );
  }

  try {
    // The native Android/iOS Firebase configuration files are provisioned by
    // the developer/CI environment and deliberately excluded from source.
    // Firebase client identifiers are never reconstructed from the supplied
    // plaintext key files.
    await Firebase.initializeApp();
    await _activateAppCheck();
    if (AppConfig.useFirebaseEmulators) {
      final host =
          !kIsWeb && Platform.isAndroid
              ? (AppConfig.firebaseEmulatorHost == '127.0.0.1'
                  ? '10.0.2.2'
                  : AppConfig.firebaseEmulatorHost)
              : AppConfig.firebaseEmulatorHost;
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    }
    return BootstrapResult(
      preferences: preferences,
      firebaseReady: true,
      startedAt: startedAt,
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Mento bootstrap',
        context: ErrorDescription('initializing Firebase services'),
      ),
    );
    return BootstrapResult(
      preferences: preferences,
      firebaseReady: false,
      firebaseError: error,
      startedAt: startedAt,
    );
  }
}

Future<void> _activateAppCheck() async {
  // Debug providers support local development. Store builds use device-backed
  // attestation so the backend can reject requests from untrusted clients.
  if (kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidDebugProvider(),
      providerApple: const AppleDebugProvider(),
    );
    return;
  }
  await FirebaseAppCheck.instance.activate(
    providerAndroid: const AndroidPlayIntegrityProvider(),
    providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );
}
