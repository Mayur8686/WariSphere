import 'package:geolocator/geolocator.dart';

/// A normalised GPS reading the rest of the app works with.
class GeoFix {
  const GeoFix({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime timestamp;
}

/// Human-readable GPS failure.
class LocationException implements Exception {
  const LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Wraps `geolocator` behind one tiny service so screens never touch the
/// plugin directly (easy to fake in tests, easy to swap later).
class LocationService {
  const LocationService();

  /// Current position. Throws [LocationException] with a user-facing message
  /// when GPS is off or permission is missing.
  Future<GeoFix> getCurrentFix() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
          'Location services are turned off. Please enable GPS and try again.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(
            'Location permission was denied. WariSathi needs it to attach your position to alerts.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
          'Location permission is permanently denied. Enable it from app settings.');
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return GeoFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (_) {
      throw const LocationException(
          'Could not get a GPS fix in time. Move to an open area and try again.');
    }
  }

  /// `true` when permission is ALREADY granted — used for passive features
  /// (e.g. "distance to camp") without nagging the user for permission.
  Future<bool> hasPermission() async {
    final LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
