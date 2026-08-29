import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// Emergency-SMS fallback: reaches the ICE (emergency) contact even with
/// ZERO internet — SMS carries a Google Maps link of the pilgrim's GPS fix.
///
/// This is a MOBILE/Offline fallback only. The automatic server-side SMS
/// (Fast2SMS/Twilio) triggered by `POST /sos` is the primary mechanism and
/// works on every platform, including Flutter Web.
///
/// Deliberately uses the OS SMS app (`sms:` deep link) instead of direct
/// SEND_SMS: no special permissions, works on every OEM, and the sender
/// stays in control before the message leaves the phone.
class SmsService {
  const SmsService();

  /// Pure message builder — unit-tested, no platform calls.
  static String buildIceMessage({
    required String senderName,
    required String typeLabel,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) {
    final StringBuffer buf = StringBuffer('🚨 EMERGENCY (WariSathi)\n');
    buf.write('$senderName needs help: $typeLabel.');
    final bool hasFix = latitude != null && longitude != null;
    if (hasFix) {
      buf.write(
          '\nLive location: https://maps.google.com/?q=$latitude,$longitude');
      if (accuracyMeters != null) {
        buf.write(accuracyMeters > 50000
            ? ' (approximate location)'
            : ' (±${accuracyMeters.round()} m)');
      }
    } else {
      buf.write('\nGPS unavailable — please call immediately.');
    }
    buf.write('\n— sent automatically by the WariSathi app');
    return buf.toString();
  }

  /// `sms:<phone>?body=<text>` deep link (Android & iOS).
  static Uri smsUri(String phone, String body) => Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: <String, String>{'body': body},
      );

  /// Opens the OS SMS app with recipient + text pre-filled — one tap to send.
  /// Returns `false` when no SMS app could be launched.
  ///
  /// Never invoked on Flutter Web: a browser tab has no SMS app to launch
  /// (and an `sms:` navigation just dead-ends). On web the automatic
  /// server-side SMS is used instead; the UI offers copy-to-clipboard.
  Future<bool> composeIceSms({
    required String phone,
    required String body,
  }) async {
    if (kIsWeb) return false;
    try {
      return await launchUrl(
        smsUri(phone, body),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
