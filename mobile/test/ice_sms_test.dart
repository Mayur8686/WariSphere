import 'package:flutter_test/flutter_test.dart';
import 'package:wari_sathi/core/services/sms_service.dart';

void main() {
  group('SmsService.buildIceMessage', () {
    test('includes maps link and accuracy when a GPS fix exists', () {
      final String msg = SmsService.buildIceMessage(
        senderName: 'Ramesh Deshmukh',
        typeLabel: 'Medical emergency',
        latitude: 18.52043,
        longitude: 73.856743,
        accuracyMeters: 11.4,
      );

      expect(msg, contains('Ramesh Deshmukh'));
      expect(msg, contains('Medical emergency'));
      expect(msg, contains('https://maps.google.com/?q=18.52043,73.856743'));
      expect(msg, contains('±11 m'));
      expect(msg, contains('WariSathi'));
    });

    test('asks the contact to call immediately when GPS is missing', () {
      final String msg = SmsService.buildIceMessage(
        senderName: 'A Warkari',
        typeLabel: 'Personal safety',
      );

      expect(msg, contains('GPS unavailable'));
      expect(msg, contains('call immediately'));
      expect(msg, isNot(contains('maps.google.com')));
    });

    test('no accuracy suffix when accuracy is unknown', () {
      final String msg = SmsService.buildIceMessage(
        senderName: 'A Warkari',
        typeLabel: 'Other help',
        latitude: 17.65,
        longitude: 75.32,
      );

      expect(msg, contains('maps.google.com'));
      expect(msg, isNot(contains('±')));
    });
  });

  group('SmsService.smsUri', () {
    test('carries recipient and encoded body', () {
      final Uri uri = SmsService.smsUri('9876500000', 'SOS! need help');

      expect(uri.scheme, 'sms');
      expect(uri.path, '9876500000');
      expect(uri.queryParameters['body'], 'SOS! need help');
    });
  });
}
