import 'package:flutter/foundation.dart';

import '../core/services/data_repository.dart';
import '../models/lost_person.dart';

/// Lost & found: submit reports offline, browse active reports, mark reunited.
class LostProvider extends ChangeNotifier {
  LostProvider({required DataRepository repository}) : _repo = repository;

  final DataRepository _repo;

  List<LostPersonReport> _reports = <LostPersonReport>[];
  bool _loading = true;
  bool _submitting = false;

  List<LostPersonReport> get reports => List<LostPersonReport>.unmodifiable(_reports);
  List<LostPersonReport> get activeReports =>
      _reports.where((LostPersonReport r) => r.status == LostReportStatus.active).toList();
  bool get loading => _loading;
  bool get submitting => _submitting;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _reports = await _repo.getLostReports();
    _loading = false;
    notifyListeners();
  }

  /// Returns the created report (with its ID) on success.
  Future<LostPersonReport?> submit({
    required LostReportType type,
    required String personName,
    required int age,
    required String gender,
    required String description,
    required String lastSeenPlace,
    required DateTime lastSeenTime,
    required String reporterName,
    required String reporterPhone,
    double? latitude,
    double? longitude,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      final LostPersonReport report = LostPersonReport(
        id: _generateId(),
        type: type,
        personName: personName,
        age: age,
        gender: gender,
        description: description,
        lastSeenPlace: lastSeenPlace,
        lastSeenTime: lastSeenTime,
        reporterName: reporterName,
        reporterPhone: reporterPhone,
        status: LostReportStatus.active,
        createdAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
      );
      await _repo.submitLostReport(report);
      _reports.insert(0, report);
      return report;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> markReunited(String reportId) async {
    final LostPersonReport report =
        _reports.firstWhere((LostPersonReport r) => r.id == reportId);
    final LostPersonReport updated = report.copyWith(status: LostReportStatus.reunited);
    await _repo.updateLostReport(updated);
    final int idx = _reports.indexWhere((LostPersonReport r) => r.id == reportId);
    if (idx >= 0) _reports[idx] = updated;
    notifyListeners();
  }

  String _generateId() {
    final String s = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return 'LP-${s.substring(s.length - 6)}';
  }
}
