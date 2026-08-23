// Reads build-time configuration without placing service secrets in the app.

abstract final class AppConfig {
  static const appName = 'Mento';
  static const applicationId = 'thulmin.icbt.mento';

  static const demoMode = bool.fromEnvironment(
    'MENTO_DEMO_MODE',
    defaultValue: false,
  );
  static const useFirebaseEmulators = bool.fromEnvironment(
    'MENTO_USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );
  static const firebaseEmulatorHost = String.fromEnvironment(
    'MENTO_FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  static const workerBaseUrl = String.fromEnvironment(
    'MENTO_WORKER_BASE_URL',
    defaultValue: 'https://mento-ai-proxy.thulminj.workers.dev',
  );
  static const mapsEnabled = bool.fromEnvironment(
    'MENTO_MAPS_ENABLED',
    defaultValue: true,
  );
  static const appleAuthEnabled = bool.fromEnvironment(
    'MENTO_APPLE_AUTH_ENABLED',
    defaultValue: false,
  );

  static bool get hasWorker {
    final uri = Uri.tryParse(workerBaseUrl);
    return uri != null && uri.isAbsolute && uri.hasAuthority;
  }
}
