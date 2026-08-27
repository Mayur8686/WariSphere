import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/sos_alert.dart';
import '../config/api_config.dart';

/// Talks to the WariSphere backend (FastAPI).
///
/// Payload builder is pure & static so it's unit-testable without network.
class ApiClient {
  const ApiClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  /// Model → API JSON. Mirrors `backend/app/schemas/sos.py`.
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
}
