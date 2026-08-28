import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/sos_alert.dart';

class ApiService {
  // For Flutter Web/Windows running on the same PC as FastAPI.
  static const String baseUrl = 'http://127.0.0.1:8000';

  Future<SosAlert> sendSos(SosAlert alert) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sos'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'user_id': alert.userId,
        'latitude': alert.latitude ?? 0.0,
        'longitude': alert.longitude ?? 0.0,
        'sos_type': alert.type.name,
        'message': alert.note ?? '',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'SOS API failed: ${response.statusCode} ${response.body}',
      );
    }

    return alert.copyWith(
      status: SosStatus.sent,
      syncPending: false,
    );
  }
}