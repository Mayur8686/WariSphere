import 'package:flutter/foundation.dart';

import '../core/services/data_repository.dart';
import '../core/services/location_service.dart';
import '../core/services/notification_service.dart';
import '../models/sos_alert.dart';

enum SosPhase { idle, locating, sending, done }

/// Owns the SOS lifecycle: GPS capture → persist offline → mock server ack.
class SosProvider extends ChangeNotifier {
  SosProvider({
    required DataRepository repository,
    required LocationService location,
    required NotificationService notifications,
  })  : _repo = repository,
        _location = location,
        _notifications = notifications;

  final DataRepository _repo;
  final LocationService _location;
  final NotificationService _notifications;

  SosPhase _phase = SosPhase.idle;
  String? _locationWarning;
  List<SosAlert> _alerts = <SosAlert>[];

  SosPhase get phase => _phase;
  String? get locationWarning => _locationWarning;
  List<SosAlert> get alerts => List<SosAlert>.unmodifiable(_alerts);
  bool get isWorking => _phase == SosPhase.locating || _phase == SosPhase.sending;

  /// Alerts not yet confirmed synced with a backend (offline-first queue).
  int get pendingSyncCount =>
      _alerts.where((SosAlert a) => a.syncPending && a.status != SosStatus.resolved).length;

  void loadHistory() {
    _alerts = _repo.mySosAlerts();
    notifyListeners();
  }

  /// Full SOS pipeline. Never throws — GPS failures degrade gracefully
  /// (alert is still raised; volunteers search the last-known corridor).
  Future<SosAlert?> sendAlert({
    required SosType type,
    required String userId,
    required String userName,
    required String userPhone,
    String? note,
  }) async {
    _locationWarning = null;
    _phase = SosPhase.locating;
    notifyListeners();

    GeoFix? fix;
    try {
      fix = await _location.getCurrentFix();
    } on LocationException catch (e) {
      _locationWarning = e.message;
    }

    _phase = SosPhase.sending;
    notifyListeners();

    final SosAlert alert = SosAlert(
      id: _generateId(),
      userId: userId,
      userName: userName,
      userPhone: userPhone,
      type: type,
      status: SosStatus.pending,
      createdAt: DateTime.now(),
      latitude: fix?.latitude,
      longitude: fix?.longitude,
      accuracyMeters: fix?.accuracyMeters,
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
    );

    final SosAlert acked = await _repo.submitSos(alert);
    _alerts.insert(0, acked);
    _phase = SosPhase.done;
    notifyListeners();

    // TODO(Phase 3): this stub becomes the FCM fan-out to nearby volunteers.
    await _notifications.showLocal(
      title: 'SOS ${acked.id}',
      body: 'Sent to volunteers & control room (${SosAlert.typeLabel(acked.type)})',
    );
    return acked;
  }

  Future<void> markResolved(String alertId) async {
    await _repo.updateSosStatus(alertId, SosStatus.resolved);
    _alerts = _alerts
        .map((SosAlert a) => a.id == alertId ? a.copyWith(status: SosStatus.resolved) : a)
        .toList();
    notifyListeners();
  }

  void resetPhase() {
    if (_phase != SosPhase.idle) {
      _phase = SosPhase.idle;
      notifyListeners();
    }
  }

  String _generateId() {
    final int stamp = DateTime.now().millisecondsSinceEpoch;
    return 'SOS-${stamp.toRadixString(36).toUpperCase().substring(stamp.toRadixString(36).length - 6)}';
  }
}
