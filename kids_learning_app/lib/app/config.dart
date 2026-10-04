import 'package:flutter/foundation.dart';

/// App version, compared with each pack's `minAppVersion`.
/// Keep in step with `version:` in pubspec.yaml.
const String kAppVersion = '0.2.0';

/// Where the pack server lives.
///
/// Development defaults to the local dev server (tools/dev_server.dart):
/// - Web (Chrome on this PC): http://localhost:8080
/// - Android emulator: http://10.0.2.2:8080 (the emulator's name for this PC)
///
/// For a real phone on the same Wi-Fi, or the real server later, run with:
///   flutter run --dart-define=PACK_SERVER=http://192.168.1.20:8080
String get packServerBase {
  const fromDefine = String.fromEnvironment('PACK_SERVER');
  if (fromDefine.isNotEmpty) return fromDefine;
  if (kIsWeb) return 'http://localhost:8080';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}
