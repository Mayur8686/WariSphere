import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';
import '../../models/lost_person.dart';
import '../../models/sos_alert.dart';
import '../../models/wari_route.dart';

/// Offline-first local persistence (shared_preferences + JSON).
///
/// Everything the user creates is written here FIRST, then (in Phase 3)
/// synced to Firebase. This is what makes the app work with zero network —
/// critical on the Wari route where connectivity drops for kilometres.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static const String _kUser = 'wari_user_v1';
  static const String _kPassword = 'wari_local_password_v1'; // mock auth only
  static const String _kSosAlerts = 'wari_sos_alerts_v1';
  static const String _kLostReports = 'wari_lost_reports_v1';
  static const String _kRoute = 'wari_route_v1';
  static const String _kCurrentStopId = 'wari_current_stop_v1';
  static const String _kCampsCache = 'wari_camps_cache_v1';

  // ---- Session / user ----
  AppUser? loadUser() => _decode(_kUser, AppUser.fromJson);

  Future<void> saveUser(AppUser user) async {
    await _prefs.setString(_kUser, jsonEncode(user.toJson()));
  }

  Future<void> clearUser() => _prefs.remove(_kUser);

  String? loadLocalPassword() => _prefs.getString(_kPassword);

  Future<void> saveLocalPassword(String password) =>
      _prefs.setString(_kPassword, password);

  Future<void> clearPassword() => _prefs.remove(_kPassword);

  // ---- SOS alerts ----
  List<SosAlert> loadSosAlerts() =>
      _decodeList(_kSosAlerts, SosAlert.fromJson);

  Future<void> upsertSosAlert(SosAlert alert) async {
    final List<SosAlert> alerts = loadSosAlerts();
    final int idx = alerts.indexWhere((SosAlert a) => a.id == alert.id);
    if (idx >= 0) {
      alerts[idx] = alert;
    } else {
      alerts.insert(0, alert);
    }
    await _writeList(_kSosAlerts, alerts.map((SosAlert a) => a.toJson()).toList());
  }

  Future<void> clearSosAlerts() => _prefs.remove(_kSosAlerts);

  // ---- Lost & found reports ----
  List<LostPersonReport> loadLostReports() =>
      _decodeList(_kLostReports, LostPersonReport.fromJson);

  Future<void> upsertLostReport(LostPersonReport report) async {
    final List<LostPersonReport> reports = loadLostReports();
    final int idx = reports.indexWhere((LostPersonReport r) => r.id == report.id);
    if (idx >= 0) {
      reports[idx] = report;
    } else {
      reports.insert(0, report);
    }
    await _writeList(
        _kLostReports, reports.map((LostPersonReport r) => r.toJson()).toList());
  }

  // ---- Wari route (cached from backend later; seeded now) ----
  WariRoute? loadRoute() => _decode(_kRoute, WariRoute.fromJson);

  Future<void> saveRoute(WariRoute route) async {
    await _prefs.setString(_kRoute, jsonEncode(route.toJson()));
  }

  String? loadCurrentStopId() => _prefs.getString(_kCurrentStopId);

  Future<void> saveCurrentStopId(String stopId) =>
      _prefs.setString(_kCurrentStopId, stopId);

  // ---- Medical camps cache ----
  List<dynamic>? rawCampsCache() => _prefs.getString(_kCampsCache) == null
      ? null
      : jsonDecode(_prefs.getString(_kCampsCache)!) as List<dynamic>;

  Future<void> saveCampsCache(List<Map<String, dynamic>> camps) =>
      _prefs.setString(_kCampsCache, jsonEncode(camps));

  // ---- helpers ----
  T? _decode<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final String? raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  List<T> _decodeList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final String? raw = _prefs.getString(key);
    if (raw == null) return <T>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((dynamic e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <T>[];
    }
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) =>
      _prefs.setString(key, jsonEncode(items));
}
