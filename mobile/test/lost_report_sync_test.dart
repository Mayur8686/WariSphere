import 'package:flutter_test/flutter_test.dart';
import 'package:wari_sathi/core/services/api_client.dart';
import 'package:wari_sathi/models/lost_person.dart';

void main() {
  final LostPersonReport report = LostPersonReport(
    id: 'LP-4KD9F2',
    type: LostReportType.lost,
    personName: 'Rambhau Kedari',
    age: 68,
    gender: 'Male',
    description: 'White kurta, orange topi, walks with a stick.',
    lastSeenPlace: 'Near Yavat toll naka',
    lastSeenTime: DateTime.parse('2026-08-28T18:30:00.000Z'),
    reporterName: 'Demo Warkari',
    reporterPhone: '9876543210',
    reporterId: 'WRI-ABC123',
    status: LostReportStatus.active,
    createdAt: DateTime.parse('2026-08-28T19:05:00.000Z'),
    latitude: 18.3712,
    longitude: 74.2671,
    photoUrl: 'http://localhost:8000/uploads/lost_persons/p.png',
    syncPending: false,
    serverId: 'abc12345-6789',
  );

  test('buildLostReportPayload maps the app model onto the API schema', () {
    final Map<String, dynamic> payload = ApiClient.buildLostReportPayload(report);

    expect(payload['client_report_id'], 'LP-4KD9F2');
    expect(payload['report_type'], 'lost');
    expect(payload['name'], 'Rambhau Kedari');
    expect(payload['age'], 68);
    expect(payload['gender'], 'Male');
    expect(payload['description'], contains('kurta'));
    expect(payload['last_seen_location'], 'Near Yavat toll naka');
    expect(payload['last_seen_time'], '2026-08-28T18:30:00.000Z');
    expect(payload['last_seen_latitude'], 18.3712);
    expect(payload['last_seen_longitude'], 74.2671);
    expect(payload['photo_url'], 'http://localhost:8000/uploads/lost_persons/p.png');
    expect(payload['reporter_id'], 'WRI-ABC123');
    expect(payload['reporter_name'], 'Demo Warkari');
    expect(payload['reporter_phone'], '9876543210');
  });

  test('buildLostReportPayload tolerates missing optional details', () {
    final Map<String, dynamic> payload = ApiClient.buildLostReportPayload(
      LostPersonReport(
        id: 'LP-MIN01',
        type: LostReportType.found,
        personName: 'Unknown boy',
        age: 10,
        gender: 'Male',
        description: 'Found near the medical camp.',
        lastSeenPlace: 'Wakhari entry camp',
        lastSeenTime: DateTime.parse('2026-08-28T09:00:00.000Z'),
        reporterName: 'Volunteer',
        reporterPhone: '9000000000',
        status: LostReportStatus.active,
        createdAt: DateTime.parse('2026-08-28T09:10:00.000Z'),
      ),
    );

    expect(payload['report_type'], 'found');
    expect(payload['last_seen_latitude'], isNull);
    expect(payload['last_seen_longitude'], isNull);
    expect(payload['photo_url'], isNull);
    expect(payload['reporter_id'], isNull);
  });

  test('model round-trips through local JSON with photo + sync fields', () {
    final Map<String, dynamic> json = report.toJson();
    final LostPersonReport restored = LostPersonReport.fromJson(json);

    expect(restored.photoUrl, report.photoUrl);
    expect(restored.serverId, report.serverId);
    expect(restored.reporterId, report.reporterId);
    expect(restored.syncPending, false);
    expect(restored.personName, report.personName);
    expect(restored.lastSeenPlace, report.lastSeenPlace);
  });

  test('model reads records written by the older app version (no photo keys)', () {
    final LostPersonReport legacy = LostPersonReport.fromJson(<String, dynamic>{
      'id': 'LP-OLD01',
      'type': 'lost',
      'personName': 'Old Report',
      'age': 50,
      'gender': 'Female',
      'description': 'Saree, speaks only Marathi.',
      'lastSeenPlace': 'Pune',
      'lastSeenTime': '2026-08-01T10:00:00.000Z',
      'reporterName': 'Someone',
      'reporterPhone': '9000000001',
      'status': 'active',
      'createdAt': '2026-08-01T10:05:00.000Z',
    });

    expect(legacy.photoUrl, isNull);
    expect(legacy.photoPath, isNull);
    expect(legacy.serverId, isNull);
    expect(legacy.syncPending, true); // stays queued like before
  });

  test('fromApi maps a backend lost_persons record onto the model', () {
    final LostPersonReport remote = LostPersonReport.fromApi(<String, dynamic>{
      'lost_person_id': 'abc12345-6789-def0',
      'client_report_id': 'LP-OTHER',
      'report_type': 'found',
      'name': 'Unknown boy',
      'age': 10,
      'gender': 'Male',
      'description': 'Found crying near the medical camp.',
      'last_seen_location': 'Wakhari entry camp help desk',
      'last_seen_time': '2026-08-28T17:15:00+00:00',
      'last_seen_latitude': 17.6688,
      'last_seen_longitude': 75.2812,
      'photo_url': '/uploads/lost_persons/abc.png',
      'reporter_name': 'Help desk 4',
      'reporter_phone': '9000000002',
      'status': 'found',
      'created_at': '2026-08-28T17:30:00+00:00',
    });

    expect(remote.id, 'SRV-ABC12345');
    expect(remote.serverId, 'abc12345-6789-def0');
    expect(remote.type, LostReportType.found);
    expect(remote.personName, 'Unknown boy');
    expect(remote.status, LostReportStatus.active);
    expect(remote.photoUrl, '/uploads/lost_persons/abc.png');
    expect(remote.syncPending, false);
    expect(remote.latitude, 17.6688);
  });
}
