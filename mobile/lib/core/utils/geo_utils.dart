import 'dart:math' as math;

/// Geo helpers: distances, map URIs.
class GeoUtils {
  GeoUtils._();

  /// Haversine distance in kilometres.
  static double distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double r = 6371.0; // Earth radius km
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLng = _deg2rad(lng2 - lng1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);

  /// Opens the default maps app at a pin (Android `geo:` / Apple Maps on iOS).
  static Uri mapUri(double lat, double lng, {String? label}) {
    final String q = label == null ? '$lat,$lng' : '$lat,$lng($label)';
    return Uri.parse('geo:$lat,$lng?q=$q');
  }

  static Uri telUri(String number) => Uri.parse('tel:$number');
}
