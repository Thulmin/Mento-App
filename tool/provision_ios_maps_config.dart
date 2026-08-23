import 'dart:io';

const _mapsKeySource = 'Google-Maps-Demo-API-Key.txt';
const _googleServiceInfo = 'ios/Runner/GoogleService-Info.plist';
const _output = 'ios/Flutter/Secrets.xcconfig';

void main() {
  final mapsKeyFile = File(_mapsKeySource);
  if (!mapsKeyFile.existsSync()) {
    stderr.writeln('Missing ignored Maps key source: $_mapsKeySource');
    exitCode = 1;
    return;
  }

  final mapsKey = mapsKeyFile.readAsStringSync().trim();
  if (mapsKey.isEmpty ||
      mapsKey.contains(RegExp(r'\s')) ||
      mapsKey == 'MAPS_KEY_NOT_CONFIGURED') {
    stderr.writeln('The ignored Maps key source is not configured.');
    exitCode = 1;
    return;
  }

  final serviceInfoFile = File(_googleServiceInfo);
  if (!serviceInfoFile.existsSync()) {
    stderr.writeln('Missing ignored Firebase iOS config: $_googleServiceInfo');
    exitCode = 1;
    return;
  }

  final serviceInfo = serviceInfoFile.readAsStringSync();
  final reversedClientId =
      RegExp(
        r'<key>REVERSED_CLIENT_ID</key>\s*<string>([^<]+)</string>',
      ).firstMatch(serviceInfo)?.group(1)?.trim();
  if (reversedClientId == null || reversedClientId.isEmpty) {
    stderr.writeln(
      'REVERSED_CLIENT_ID is absent from the Firebase iOS config.',
    );
    exitCode = 1;
    return;
  }

  final output = File(_output);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '// Generated from ignored local configuration. Do not commit.\n'
    'MENTO_IOS_MAPS_API_KEY=$mapsKey\n'
    'GOOGLE_REVERSED_CLIENT_ID=$reversedClientId\n',
    flush: true,
  );
  stdout.writeln('Provisioned ignored iOS Maps and Google sign-in settings.');
}
