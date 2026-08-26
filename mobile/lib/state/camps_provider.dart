import 'package:flutter/foundation.dart';

import '../core/services/data_repository.dart';
import '../core/services/location_service.dart';
import '../core/utils/geo_utils.dart';
import '../models/medical_camp.dart';

enum CampFilter { all, open24x7, withDoctors, withBeds }

/// Medical camps list + search/filter + optional "distance from me".
class CampsProvider extends ChangeNotifier {
  CampsProvider({required DataRepository repository, required LocationService location})
      : _repo = repository,
        _location = location;

  final DataRepository _repo;
  final LocationService _location;

  List<MedicalCamp> _camps = <MedicalCamp>[];
  bool _loading = true;
  String _query = '';
  CampFilter _filter = CampFilter.all;
  ({double latitude, double longitude})? _myPosition;

  List<MedicalCamp> get camps => _filtered();
  bool get loading => _loading;
  CampFilter get filter => _filter;
  ({double latitude, double longitude})? get myPosition => _myPosition;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _camps = await _repo.getMedicalCamps();
    _loading = false;
    notifyListeners();
  }

  /// Passive distance: only computes if permission was already granted,
  /// so opening this screen never throws a permission dialog at the user.
  Future<void> attachDistanceIfPermitted() async {
    try {
      if (await _location.hasPermission()) {
        final GeoFix fix = await _location.getCurrentFix();
        _myPosition = (latitude: fix.latitude, longitude: fix.longitude);
        notifyListeners();
      }
    } on LocationException {
      // distance display is a nice-to-have; ignore silently
    }
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  void setFilter(CampFilter f) {
    _filter = f;
    notifyListeners();
  }

  double? distanceKmFromMe(MedicalCamp camp) {
    final ({double latitude, double longitude})? pos = _myPosition;
    if (pos == null) return null;
    return GeoUtils.distanceKm(
        pos.latitude, pos.longitude, camp.latitude, camp.longitude);
  }

  List<MedicalCamp> _filtered() {
    final String q = _query.trim().toLowerCase();
    return _camps.where((MedicalCamp c) {
      if (_filter == CampFilter.open24x7 && !c.is24x7) return false;
      if (_filter == CampFilter.withDoctors && c.doctors < 3) return false;
      if (_filter == CampFilter.withBeds && c.beds < 10) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.stopName.toLowerCase().contains(q) ||
          c.organization.toLowerCase().contains(q) ||
          c.services.any((String s) => s.toLowerCase().contains(q));
    }).toList();
  }
}
