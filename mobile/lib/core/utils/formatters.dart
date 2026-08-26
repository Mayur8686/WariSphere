import 'package:intl/intl.dart';

/// Small date/number formatting helpers.
class Formatters {
  Formatters._();

  static String dateTimeShort(DateTime dt) =>
      DateFormat('d MMM, hh:mm a').format(dt);

  static String dateLong(DateTime dt) => DateFormat('EEEE, d MMMM y').format(dt);

  static String timeOnly(DateTime dt) => DateFormat('hh:mm a').format(dt);

  /// "just now", "5 min ago", "3 hr ago", "2 days ago".
  static String timeAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return DateFormat('d MMM').format(dt);
  }

  static String latLng(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  static String km(double value) =>
      value < 10 ? '${value.toStringAsFixed(1)} km' : '${value.round()} km';
}
