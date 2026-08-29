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
      emergencyContactName: 'Sunita Patil',
      emergencyContactPhone: '9822011223',
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
    // ICE contact is forwarded for the automatic server-side SMS.
    expect(payload['emergency_contact_name'], 'Sunita Patil');
    expect(payload['emergency_contact_phone'], '9822011223');
  });

  test('buildSosPayload sends null ICE fields when no contact is registered',
      () {
    final SosAlert alert = SosAlert(
      id: 'SOS-TEST03',
      userId: 'WRI-NO-ICE',
      userName: 'Anonymous',
      userPhone: '',
      type: SosType.other,
      status: SosStatus.pending,
      createdAt: DateTime.parse('2026-01-15T10:30:00.000Z'),
    );

    final Map<String, dynamic> payload = ApiClient.buildSosPayload(alert);

    expect(payload['emergency_contact_name'], isNull);
    expect(payload['emergency_contact_phone'], isNull);
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
    // Defaults: no ICE contact until the profile provides one.
    expect(payload['emergency_contact_name'], isNull);
    expect(payload['emergency_contact_phone'], isNull);
  });

  test('SosAlert keeps the ICE contact through copyWith and JSON round-trip',
      () {
    final SosAlert alert = SosAlert(
      id: 'SOS-TEST04',
      userId: 'WRI-ABC123',
      userName: 'Mayur Patil',
      userPhone: '9876543210',
      type: SosType.accident,
      status: SosStatus.pending,
      createdAt: DateTime.parse('2026-01-15T10:30:00.000Z'),
      emergencyContactName: 'Sunita Patil',
      emergencyContactPhone: '9822011223',
    );

    final SosAlert roundTripped = SosAlert.fromJson(alert.toJson());
    expect(roundTripped.emergencyContactName, 'Sunita Patil');
    expect(roundTripped.emergencyContactPhone, '9822011223');

    // copyWith must not drop the ICE fields when updating sync state.
    final SosAlert synced =
        alert.copyWith(status: SosStatus.sent, syncPending: false);
    expect(synced.emergencyContactName, 'Sunita Patil');
    expect(synced.emergencyContactPhone, '9822011223');
  });

  test('SosAlert defaults the ICE contact to empty for old local records', () {
    final SosAlert legacy = SosAlert.fromJson(<String, dynamic>{
      'id': 'SOS-OLD01',
      'userId': 'WRI-OLD',
      'userName': 'Old Pilgrim',
      'userPhone': '',
      'type': 'medical',
      'status': 'pending',
      'createdAt': '2026-08-01T10:00:00.000Z',
    });
    expect(legacy.emergencyContactName, '');
    expect(legacy.emergencyContactPhone, '');
  });
}
