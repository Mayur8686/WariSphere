/// Backend API configuration.
///
/// Default points at the Android-emulator alias for your laptop's
/// localhost (10.0.2.2 = host machine from the emulator).
///
/// Real phone on the same Wi-Fi? Run with your laptop's LAN IP:
///
///   flutter run --dart-define=WARISATHI_API_URL=http://192.168.1.23:8000
///
/// (find the IP with `ipconfig` → IPv4 Address; allow Python through the
/// Windows Firewall prompt the first time uvicorn starts)
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'WARISATHI_API_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const Duration timeout = Duration(seconds: 10);
}
