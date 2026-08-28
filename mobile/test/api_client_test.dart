import 'package:flutter_test/flutter_test.dart';
import 'package:wari_sathi/core/services/api_client.dart';
import 'package:wari_sathi/models/sos_alert.dart';

void main() {
  test('buildSosPayload maps the app model onto the API schema', () {
    final SosAlert alert = SosAlert(
      id: 'SOS-TEST01',
      userId: 'WRI-ABC123',
      userName: 'Mayur Patil',
      userPhone: '9876543210',
      type: SosType.medical,
      status: SosStatus.pending,
      createdAt: DateTime.parse('2026-01-15T10:30:00.000Z'),
      latitude: 18.5204,
      longitude: 73.8567,
      accuracyMeters: 12.0,
      note: 'near the ghat',
    );

    final Map<String, dynamic> payload = ApiClient.buildSosPayload(alert);

    expect(payload['user_id'], 'WRI-ABC123');
    expect(payload['user_name'], 'Mayur Patil');
    expect(payload['user_phone'], '9876543210');
    expect(payload['sos_type'], 'medical');
    expect(payload['message'], 'near the ghat');
    expect(payload['latitude'], 18.5204);
    expect(payload['longitude'], 73.8567);
    expect(payload['accuracy_meters'], 12.0);
  });

  test('buildSosPayload tolerates a missing GPS fix and note', () {
    final SosAlert alert = SosAlert(
      id: 'SOS-TEST02',
      userId: 'WRI-XYZ',
      userName: 'Unknown',
      userPhone: '',
      type: SosType.safety,
      status: SosStatus.pending,
      createdAt: DateTime.parse('2026-01-15T10:30:00.000Z'),
    );

    final Map<String, dynamic> payload = ApiClient.buildSosPayload(alert);

    expect(payload['latitude'], isNull);
    expect(payload['longitude'], isNull);
    expect(payload['accuracy_meters'], isNull);
    expect(payload['message'], isNull);
    expect(payload['sos_type'], 'safety');
  });
}
