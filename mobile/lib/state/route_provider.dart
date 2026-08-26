import 'package:flutter/foundation.dart';

import '../core/services/data_repository.dart';
import '../models/wari_route.dart';

/// Wari route data + the pilgrim's self-declared current halt
/// (persisted offline — useful when GPS is unreliable on foot).
class RouteProvider extends ChangeNotifier {
  RouteProvider({required DataRepository repository}) : _repo = repository {
    _currentStopId = _repo.currentStopId;
  }

  final DataRepository _repo;

  WariRoute? _route;
  String? _currentStopId;
  bool _loading = true;

  WariRoute? get route => _route;
  String? get currentStopId => _currentStopId;
  bool get loading => _loading;

  RouteStop? get currentStop {
    final List<RouteStop> stops = _route?.stops ?? const <RouteStop>[];
    if (stops.isEmpty) return null;
    return stops.firstWhere(
      (RouteStop s) => s.id == _currentStopId,
      orElse: () => stops.first,
    );
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _route = await _repo.getWariRoute();
    _loading = false;
    notifyListeners();
  }

  Future<void> setCurrentStop(String stopId) async {
    _currentStopId = stopId;
    notifyListeners();
    await _repo.saveCurrentStop(stopId);
  }
}
