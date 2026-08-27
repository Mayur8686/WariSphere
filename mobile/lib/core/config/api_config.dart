import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Backend API configuration — platform-aware defaults.
///
/// Override from the command line on any platform:
///
///   flutter run --dart-define=WARISATHI_API_URL=http://192.168.1.23:8000
///
/// Defaults:
///  - Flutter WEB (`flutter run -d chrome`) → http://localhost:8000
///  - Android **emulator** → http://10.0.2.2:8000 (emulator's alias for
///    the host laptop's localhost)
///  - Real phone → pass your laptop's LAN IP via --dart-define
///    (find it with `ipconfig` → IPv4 Address; allow Python through the
///    Windows Firewall prompt the first time uvicorn starts)
class ApiConfig {
  ApiConfig._();

  static const String _override = String.fromEnvironment('WARISATHI_API_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static const Duration timeout = Duration(seconds: 10);
}
