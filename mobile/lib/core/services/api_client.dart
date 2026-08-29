import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/lost_person.dart';
import '../../models/sos_alert.dart';
import '../config/api_config.dart';

/// Talks to the WariSphere backend (FastAPI).
///
/// Payload builders are pure & static so they're unit-testable without
/// network. Network methods NEVER throw — any failure (offline, timeout,
/// 5xx) returns false/null/[] so callers keep data queued offline-first.
class ApiClient {
  const ApiClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  // =====================================================================
  // SOS
  // =====================================================================

  /// Model → API JSON. Mirrors `backend/app/schemas/sos.py`.
  ///
  /// The ICE contact is forwarded so the backend can send the automatic
  /// server-side SMS to it (in addition to the control-room numbers
  /// configured on the server via SOS_CONTROL_ROOM_NUMBERS).
  static Map<String, dynamic> buildSosPayload(SosAlert alert) {
    return <String, dynamic>{
      'user_id': alert.userId,
      'latitude': alert.latitude,
      'longitude': alert.longitude,
      'sos_type': alert.type.name,
      'message': alert.note,
      'user_name': alert.userName,
      'user_phone': alert.userPhone,
      'accuracy_meters': alert.accuracyMeters,
      'emergency_contact_name':
          alert.emergencyContactName.isEmpty ? null : alert.emergencyContactName,
      'emergency_contact_phone':
          alert.emergencyContactPhone.isEmpty ? null : alert.emergencyContactPhone,
    };
  }

  /// POSTs an SOS to the backend. Returns `true` when the server accepted
  /// it. Never throws — any failure (offline, timeout, 5xx) returns false
  /// and the caller keeps the alert queued for retry (offline-first).
  Future<bool> postSos(SosAlert alert) async {
    final Uri url = Uri.parse('${ApiConfig.baseUrl}/sos');
    try {
      final http.Client client = _client ?? http.Client();
      final http.Response resp = await client
          .post(
            url,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(buildSosPayload(alert)),
          )
          .timeout(ApiConfig.timeout);
      if (_client == null) client.close();
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } on SocketException {
      return false; // no network at all
    } on HttpException {
      return false;
    } catch (_) {
      return false; // timeout, bad JSON, 5xx …
    }
  }

  // =====================================================================
  // Lost & found
  // =====================================================================

  /// Model → API JSON. Mirrors `backend/app/schemas/lost_person.py`.
  static Map<String, dynamic> buildLostReportPayload(LostPersonReport report) {
    return <String, dynamic>{
      'client_report_id': report.id,
      'report_type': report.type.name,
      'name': report.personName,
      'age': report.age,
      'gender': report.gender,
      'description': report.description,
      'last_seen_location': report.lastSeenPlace,
      'last_seen_time': report.lastSeenTime.toUtc().toIso8601String(),
      'last_seen_latitude': report.latitude,
      'last_seen_longitude': report.longitude,
      'photo_url': report.photoUrl,
      'reporter_id': report.reporterId,
      'reporter_name': report.reporterName,
      'reporter_phone': report.reporterPhone,
    };
  }

  /// Stores the report in the backend database. Returns the saved record
  /// (incl. `lost_person_id`) on success, `null` on any failure.
  Future<Map<String, dynamic>?> postLostReport(LostPersonReport report) async {
    final Uri url = Uri.parse('${ApiConfig.baseUrl}/lost-person');
    try {
      final http.Client client = _client ?? http.Client();
      final http.Response resp = await client
          .post(
            url,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(buildLostReportPayload(report)),
          )
          .timeout(ApiConfig.timeout);
      if (_client == null) client.close();
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return null; // offline, timeout, bad JSON … keep the report queued
    }
  }

  /// Uploads the person's photo (multipart) and returns its URL, or `null`
  /// when the upload failed — the report is then synced without a photo
  /// and can be re-attached on retry from [LostPersonReport.photoPath].
  Future<String?> uploadLostPersonPhoto(
    Uint8List bytes, {
    String? clientReportId,
    String? filename,
  }) async {
    final Uri url = Uri.parse('${ApiConfig.baseUrl}/lost-person/photo');
    try {
      final http.MultipartRequest request = http.MultipartRequest('POST', url)
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: (filename == null || filename.trim().isEmpty)
              ? 'photo.jpg'
              : filename,
        ));
      if (clientReportId != null && clientReportId.isNotEmpty) {
        request.fields['client_report_id'] = clientReportId;
      }

      final http.Client client = _client ?? http.Client();
      final http.StreamedResponse streamed =
          await client.send(request).timeout(ApiConfig.timeout);
      final http.Response resp = await http.Response.fromStream(streamed);
      if (_client == null) client.close();
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final String? photoUrl =
          (jsonDecode(resp.body) as Map<String, dynamic>)['photo_url']
              as String?;
      if (photoUrl == null || photoUrl.isEmpty) return null;
      // Dev-mode URLs are relative (e.g. /uploads/…) — make them absolute.
      if (photoUrl.startsWith('/')) {
        return '${ApiConfig.baseUrl}$photoUrl';
      }
      return photoUrl;
    } catch (_) {
      return null;
    }
  }

  /// Community reports from the backend (newest first). Empty list on
  /// failure — never throws.
  Future<List<Map<String, dynamic>>> fetchLostReports({int limit = 50}) async {
    final Uri url =
        Uri.parse('${ApiConfig.baseUrl}/lost-person?limit=$limit');
    try {
      final http.Client client = _client ?? http.Client();
      final http.Response resp =
          await client.get(url).timeout(ApiConfig.timeout);
      if (_client == null) client.close();
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final List<dynamic> reports =
          (jsonDecode(resp.body) as Map<String, dynamic>)['reports']
              as List<dynamic>? ??
          const <dynamic>[];
      return reports
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Marks a synced report as reunited on the backend (best-effort).
  Future<bool> markLostReportReunited(String serverId) async {
    final Uri url =
        Uri.parse('${ApiConfig.baseUrl}/lost-person/$serverId/status');
    try {
      final http.Client client = _client ?? http.Client();
      final http.Response resp = await client
          .patch(
            url,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{'status': 'reunited'}),
          )
          .timeout(ApiConfig.timeout);
      if (_client == null) client.close();
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
