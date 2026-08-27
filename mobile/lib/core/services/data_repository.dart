import '../../models/lost_person.dart';
import '../../models/medical_camp.dart';
import '../../models/sos_alert.dart';
import '../../models/wari_route.dart';
import 'api_client.dart';
import 'storage_service.dart';

/// Single door to the app's data.
///
/// Pattern used everywhere: **cache-first** (works with zero network),
/// then a "remote" fetch — which in Phase 1/2 is the seeded mock, and now
/// for SOS it also syncs to the WariSphere backend when reachable.
class DataRepository {
  DataRepository({required StorageService storage, ApiClient? apiClient})
      : _storage = storage,
        _apiClient = apiClient;

  final StorageService _storage;
  final ApiClient? _apiClient;

  // =====================================================================
  // SOS
  // =====================================================================

  /// Offline-first SOS pipeline:
  /// 1. persist locally IMMEDIATELY (never lose an alert),
  /// 2. try the backend — on success mark `syncPending: false`,
  /// 3. on failure the alert stays queued; [retryPendingSync] drains later.
  Future<SosAlert> submitSos(SosAlert alert) async {
    final SosAlert saved =
        alert.copyWith(status: SosStatus.pending, syncPending: true);
    await _storage.upsertSosAlert(saved);

    final SosAlert synced = await _syncAlert(saved);
    await _storage.upsertSosAlert(synced);
    return synced;
  }

  Future<SosAlert> _syncAlert(SosAlert alert) async {
    final ApiClient? api = _apiClient;
    if (api == null) {
      // No backend configured (Phase 1/2 mock): pretend the server acked
      // but keep the pending-sync badge honest.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return alert.copyWith(status: SosStatus.sent);
    }
    final bool ok = await api.postSos(alert);
    if (ok) {
      return alert.copyWith(status: SosStatus.sent, syncPending: false);
    }
    return alert; // stays queued
  }

  /// Re-attempts backend sync for queued alerts (call when the SOS screen
  /// opens / connectivity returns).
  ///
  /// TODO(Phase 3): trigger automatically via connectivity_plus and add
  /// exponential backoff.
  Future<void> retryPendingSync() async {
    final ApiClient? api = _apiClient;
    if (api == null) return;
    final List<SosAlert> queued = _storage
        .loadSosAlerts()
        .where(
          (SosAlert a) => a.syncPending && a.status != SosStatus.resolved,
        )
        .toList();
    for (final SosAlert alert in queued.take(10)) {
      final SosAlert synced = await _syncAlert(alert);
      await _storage.upsertSosAlert(synced);
    }
  }

  Future<void> updateSosStatus(String alertId, SosStatus status) async {
    final List<SosAlert> alerts = _storage.loadSosAlerts();
    for (final SosAlert a in alerts) {
      if (a.id == alertId) {
        await _storage.upsertSosAlert(a.copyWith(status: status));
        return;
      }
    }
  }

  List<SosAlert> mySosAlerts() => _storage.loadSosAlerts();

  // =====================================================================
  // Medical camps
  // =====================================================================

  /// Cache-first: returns on-device cache if present; otherwise the seeded
  /// sample set, which is then cached.
  ///
  /// TODO(Phase 3): read `medical_camps` collection, write into cache,
  /// refresh in background when online.
  Future<List<MedicalCamp>> getMedicalCamps({bool forceRefresh = false}) async {
    final List<dynamic>? cached = _storage.rawCampsCache();
    if (!forceRefresh && cached != null && cached.isNotEmpty) {
      return cached
          .map((dynamic e) =>
              MedicalCamp.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    await Future<void>.delayed(const Duration(milliseconds: 400)); // fake fetch
    final List<MedicalCamp> seed = seedMedicalCamps();
    await _storage.saveCampsCache(
        seed.map((MedicalCamp c) => c.toJson()).toList());
    return seed;
  }

  // =====================================================================
  // Lost & found
  // =====================================================================

  /// User-created reports live locally; sample community reports are seeded
  /// so the list is never empty during demos.
  ///
  /// TODO(Phase 3): Firestore `lost_reports` collection with real-time
  /// listener; `syncPending` records pushed when connectivity returns.
  Future<List<LostPersonReport>> getLostReports() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final List<LostPersonReport> mine = _storage.loadLostReports();
    final List<LostPersonReport> samples = seedLostReports();
    return <LostPersonReport>[...mine, ...samples];
  }

  Future<void> submitLostReport(LostPersonReport report) =>
      _storage.upsertLostReport(report);

  Future<void> updateLostReport(LostPersonReport report) =>
      _storage.upsertLostReport(report);

  // =====================================================================
  // Wari route
  // =====================================================================

  /// TODO(Phase 3): fetched from Firestore (`wari_route` doc maintained by
  /// admins), cached on-device for offline use — same cache-first pattern.
  Future<WariRoute> getWariRoute() async {
    final WariRoute? cached = _storage.loadRoute();
    if (cached != null) return cached;
    await _storage.saveRoute(seedWariRoute());
    return seedWariRoute();
  }

  Future<void> saveCurrentStop(String stopId) =>
      _storage.saveCurrentStopId(stopId);

  String? get currentStopId => _storage.loadCurrentStopId();

  // =====================================================================
  // Seeded sample data (replace with admin feed in Phase 3)
  // =====================================================================

  static List<MedicalCamp> seedMedicalCamps() {
    return const <MedicalCamp>[
      MedicalCamp(
        id: 'camp-alandi-01',
        name: 'Alandi Ghat Base Camp',
        organization: 'Wari Arogya Seva Trust',
        stopName: 'Alandi (Start)',
        latitude: 18.6784,
        longitude: 73.8966,
        services: ['General OPD', 'Cardiac screening', 'ORS & hydration', 'Ambulance'],
        doctors: 6,
        beds: 20,
        openFrom: '00:00',
        openTo: '23:59',
        is24x7: true,
        contact: '9822011223',
      ),
      MedicalCamp(
        id: 'camp-pune-01',
        name: 'Pune Transit Medical Post',
        organization: 'Pune Municipal Corp. Health',
        stopName: 'Pune',
        latitude: 18.5231,
        longitude: 73.8510,
        services: ['General OPD', 'First aid', 'Medicines'],
        doctors: 3,
        beds: 8,
        openFrom: '06:00',
        openTo: '22:00',
        is24x7: false,
        contact: '9822044556',
      ),
      MedicalCamp(
        id: 'camp-yavat-01',
        name: 'Yavat Highway Camp',
        organization: 'Rotary Wari Seva',
        stopName: 'Yavat',
        latitude: 18.3720,
        longitude: 74.2690,
        services: ['General OPD', 'Ortho & blisters', 'ORS & hydration'],
        doctors: 2,
        beds: 6,
        openFrom: '05:00',
        openTo: '23:00',
        is24x7: false,
        contact: '9822077889',
      ),
      MedicalCamp(
        id: 'camp-patas-01',
        name: 'Patas Palkhi Camp',
        organization: 'Wari Arogya Seva Trust',
        stopName: 'Patas',
        latitude: 18.2830,
        longitude: 74.1980,
        services: ['First aid', 'ORS & hydration', 'Ambulance'],
        doctors: 2,
        beds: 5,
        openFrom: '05:00',
        openTo: '22:00',
        is24x7: false,
      ),
      MedicalCamp(
        id: 'camp-tembhurni-01',
        name: 'Tembhurni Seva Kendra',
        organization: 'Lions Club Wari Seva',
        stopName: 'Tembhurni',
        latitude: 18.0790,
        longitude: 74.5560,
        services: ['General OPD', 'Dressing & fractures', 'Ambulance'],
        doctors: 3,
        beds: 10,
        openFrom: '00:00',
        openTo: '23:59',
        is24x7: true,
        contact: '9822099001',
      ),
      MedicalCamp(
        id: 'camp-malshiras-01',
        name: 'Malshiras Rural Support Camp',
        organization: 'Rural Hospital Malshiras',
        stopName: 'Malshiras',
        latitude: 17.8530,
        longitude: 74.9810,
        services: ['General OPD', 'IV fluids', 'Ambulance'],
        doctors: 4,
        beds: 12,
        openFrom: '00:00',
        openTo: '23:59',
        is24x7: true,
        contact: '9822133445',
      ),
      MedicalCamp(
        id: 'camp-wakhari-01',
        name: 'Wakhari Entry Camp',
        organization: 'Pandharpur Wari Seva Samiti',
        stopName: 'Wakhari (Pandharpur entry)',
        latitude: 17.6690,
        longitude: 75.2820,
        services: ['First aid', 'ORS & hydration', 'Rest shade', 'Ambulance'],
        doctors: 3,
        beds: 15,
        openFrom: '00:00',
        openTo: '23:59',
        is24x7: true,
        contact: '9822155667',
      ),
      MedicalCamp(
        id: 'camp-pandharpur-01',
        name: 'Chandrabhaga Main Camp',
        organization: 'District Health Office',
        stopName: 'Pandharpur',
        latitude: 17.6780,
        longitude: 75.3300,
        services: [
          'General OPD',
          'Cardiac & ICU van',
          'Dialysis support',
          'Pharmacy',
          'Ambulance fleet',
        ],
        doctors: 12,
        beds: 40,
        openFrom: '00:00',
        openTo: '23:59',
        is24x7: true,
        contact: '9822177889',
      ),
    ];
  }

  static List<LostPersonReport> seedLostReports() {
    final DateTime now = DateTime.now();
    return <LostPersonReport>[
      LostPersonReport(
        id: 'LP-DEMO01',
        type: LostReportType.lost,
        personName: 'Rambhau Kedari',
        age: 68,
        gender: 'Male',
        description:
            'White kurta, orange topi, walks with a stick. Speaks Marathi. Hard of hearing in left ear.',
        lastSeenPlace: 'Near Yavat toll naka, wari margin',
        lastSeenTime: now.subtract(const Duration(hours: 5)),
        reporterName: 'Sample report',
        reporterPhone: '9000000000',
        status: LostReportStatus.active,
        createdAt: now.subtract(const Duration(hours: 4, minutes: 40)),
        latitude: 18.3712,
        longitude: 74.2671,
        syncPending: false,
      ),
      LostPersonReport(
        id: 'LP-DEMO02',
        type: LostReportType.found,
        personName: 'Unknown boy (approx. 10 yrs)',
        age: 10,
        gender: 'Male',
        description:
            'Found crying near the medical camp. Green shirt, black shorts. Currently at Wakhari entry camp.',
        lastSeenPlace: 'Wakhari entry camp help desk',
        lastSeenTime: now.subtract(const Duration(hours: 1, minutes: 15)),
        reporterName: 'Sample report',
        reporterPhone: '9000000000',
        status: LostReportStatus.active,
        createdAt: now.subtract(const Duration(hours: 1)),
        latitude: 17.6688,
        longitude: 75.2812,
        syncPending: false,
      ),
    ];
  }

  static WariRoute seedWariRoute() {
    return const WariRoute(
      id: 'route-ashadhi-2026',
      title: 'Alandi → Pandharpur (Dnyaneshwar Maharaj Palkhi)',
      subtitle:
          'Dehu palkhi joins at Pune. Indicative schedule — official halts are published by the Wari Seva committees.',
      totalKm: 250,
      totalDays: 19,
      stops: <RouteStop>[
        RouteStop(
          id: 'stop-alandi',
          day: 1,
          name: 'Alandi',
          dateLabel: 'Day 1',
          distanceFromStartKm: 0,
          description:
              'Dnyaneshwar Mauli temple, Indrayani ghat. Palkhi procession begins with dindi formations.',
          latitude: 18.6784,
          longitude: 73.8966,
        ),
        RouteStop(
          id: 'stop-pune',
          day: 3,
          name: 'Pune',
          dateLabel: 'Day 3',
          distanceFromStartKm: 22,
          description:
              'Dehu palkhi joins. Night halt around Bhawani peth / Nana wada area.',
          latitude: 18.5231,
          longitude: 73.8510,
        ),
        RouteStop(
          id: 'stop-yavat',
          day: 6,
          name: 'Yavat',
          dateLabel: 'Day 6',
          distanceFromStartKm: 65,
          description: 'First long highway stretch. Major medical & water camps.',
          latitude: 18.3720,
          longitude: 74.2690,
        ),
        RouteStop(
          id: 'stop-patas',
          day: 9,
          name: 'Patas',
          dateLabel: 'Day 9',
          distanceFromStartKm: 100,
          description: 'Rest day for many dindis. Big bhajan sand in the evening.',
          latitude: 18.2830,
          longitude: 74.1980,
        ),
        RouteStop(
          id: 'stop-tembhurni',
          day: 12,
          name: 'Tembhurni',
          dateLabel: 'Day 12',
          distanceFromStartKm: 150,
          description: 'Key logistics halt — food seva, medical camp, shoe repair.',
          latitude: 18.0790,
          longitude: 74.5560,
        ),
        RouteStop(
          id: 'stop-malshiras',
          day: 15,
          name: 'Malshiras',
          dateLabel: 'Day 15',
          distanceFromStartKm: 190,
          description: 'Rural hospital coordinates extra beds for the wari week.',
          latitude: 17.8530,
          longitude: 74.9810,
        ),
        RouteStop(
          id: 'stop-wakhari',
          day: 18,
          name: 'Wakhari',
          dateLabel: 'Day 18',
          distanceFromStartKm: 240,
          description:
              'Entry point of Pandharpur. Chandrabhaga darshan queue management starts here.',
          latitude: 17.6690,
          longitude: 75.2820,
        ),
        RouteStop(
          id: 'stop-pandharpur',
          day: 19,
          name: 'Pandharpur',
          dateLabel: 'Ashadhi Ekadashi',
          distanceFromStartKm: 250,
          description:
              'Vitthal darshan. Lost-person help desks at all temple gates.',
          latitude: 17.6780,
          longitude: 75.3300,
        ),
      ],
    );
  }
}
