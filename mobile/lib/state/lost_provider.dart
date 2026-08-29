

import 'package:flutter/foundation.dart';

import '../core/services/data_repository.dart';
import '../models/lost_person.dart';

/// Lost & found: submit reports offline, browse active reports, mark reunited.
///
/// Submitting now follows the SOS pipeline: the report is saved on-device
/// first, then its details (+ photo, when one was picked) are pushed to the
/// WariSphere backend database. Reports that fail to reach the backend stay
/// queued and are retried by [refresh].
class LostProvider extends ChangeNotifier {
  LostProvider({required DataRepository repository}) : _repo = repository;

  final DataRepository _repo;

  List<LostPersonReport> _reports = <LostPersonReport>[];
  bool _loading = true;
  bool _submitting = false;
  bool _syncing = false;

  List<LostPersonReport> get reports => List<LostPersonReport>.unmodifiable(_reports);
  List<LostPersonReport> get activeReports =>
      _reports.where((LostPersonReport r) => r.status == LostReportStatus.active).toList();
  bool get loading => _loading;
  bool get submitting => _submitting;
  bool get syncing => _syncing;

  /// Reports still waiting to reach the backend database (offline queue).
  int get pendingSyncCount =>
      _reports.where((LostPersonReport r) => r.syncPending).length;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _reports = await _repo.getLostReports();
    _loading = false;
    notifyListeners();
    await refresh(); // silent best-effort sync + community reports
  }

  /// Retries queued reports and pulls community reports from the backend
  /// (pull-to-refresh, or called silently after [load]).
  Future<void> refresh() async {
    _syncing = true;
    notifyListeners();
    try {
      await _repo.retryPendingLostSync();

      final List<LostPersonReport> remote = await _repo.fetchRemoteLostReports();
      final List<LostPersonReport> mine = _repo.localLostReports();

      // Merge: keep local reports, add backend ones we don't already have
      // (matched by their server ID), then the demo samples.
      final Set<String> knownServerIds = <String>{
        for (final LostPersonReport r in mine)
          if (r.serverId != null) r.serverId!,
      };
      final List<LostPersonReport> fresh = remote
          .where((LostPersonReport r) =>
              r.serverId != null && !knownServerIds.contains(r.serverId))
          .toList();

      // Reflect remote status changes (e.g. reunited at another help desk).
      final Map<String, LostPersonReport> byServerIds = <String, LostPersonReport>{
        for (final LostPersonReport r in remote)
          if (r.serverId != null) r.serverId!: r,
      };
      for (int i = 0; i < mine.length; i++) {
        final String? sid = mine[i].serverId;
        if (sid != null && byServerIds.containsKey(sid)) {
          mine[i] = mine[i].copyWith(status: byServerIds[sid]!.status);
        }
      }

      _reports = <LostPersonReport>[
        ...mine,
        ...fresh,
        ...DataRepository.seedLostReports(),
      ];
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Returns the created report (with its ID) on success.
  ///
  /// `photoBytes`/`photoFilename` come straight from the image picker;
  /// `photoPath` is kept with the report so a queued upload can be retried.
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
    String? reporterId,
    double? latitude,
    double? longitude,
    Uint8List? photoBytes,
    String? photoFilename,
    String? photoPath,
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
        reporterId: reporterId,
        status: LostReportStatus.active,
        createdAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        photoPath: photoPath,
      );
      final LostPersonReport saved = await _repo.submitLostReportWithPhoto(
        report,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
      _reports.insert(0, saved);
      return saved;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> markReunited(String reportId) async {
    final LostPersonReport report =
        _reports.firstWhere((LostPersonReport r) => r.id == reportId);
    await _repo.markLostReportReunited(report);
    final LostPersonReport updated = report.copyWith(status: LostReportStatus.reunited);
    final int idx = _reports.indexWhere((LostPersonReport r) => r.id == reportId);
    if (idx >= 0) _reports[idx] = updated;
    notifyListeners();
  }

  String _generateId() {
    final String s = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return 'LP-${s.substring(s.length - 6)}';
  }
}
