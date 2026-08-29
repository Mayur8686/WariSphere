/// Lost / found person report created by a Warkari from the app.
enum LostReportType { lost, found }

enum LostReportStatus { active, reunited }

class LostPersonReport {
  const LostPersonReport({
    required this.id,
    required this.type,
    required this.personName,
    required this.age,
    required this.gender,
    required this.description,
    required this.lastSeenPlace,
    required this.lastSeenTime,
    required this.reporterName,
    required this.reporterPhone,
    required this.status,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.syncPending = true,
    this.reporterId,
    this.photoUrl,
    this.photoPath,
    this.serverId,
  });

  final String id; // e.g. LP-4KD9F2
  final LostReportType type;
  final String personName;
  final int age;
  final String gender;
  final String description; // clothes, build, identifying marks, language…
  final String lastSeenPlace;
  final DateTime lastSeenTime;
  final String reporterName;
  final String reporterPhone;
  final LostReportStatus status;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

  /// True until synced with the backend.
  final bool syncPending;

  final String? reporterId; // WRI-XXXX of the reporting Warkari (sent to API)

  /// Photo of the person, as served by the backend (after upload succeeds).
  final String? photoUrl;

  /// Local path of the picked photo (kept so a queued report can be uploaded
  /// later; empty on Flutter web where bytes are used directly).
  final String? photoPath;

  /// Backend `lost_person_id` once the report reached the database.
  final String? serverId;

  LostPersonReport copyWith({
    LostReportStatus? status,
    bool? syncPending,
    String? photoUrl,
    String? serverId,
  }) {
    return LostPersonReport(
      id: id,
      type: type,
      personName: personName,
      age: age,
      gender: gender,
      description: description,
      lastSeenPlace: lastSeenPlace,
      lastSeenTime: lastSeenTime,
      reporterName: reporterName,
      reporterPhone: reporterPhone,
      status: status ?? this.status,
      createdAt: createdAt,
      latitude: latitude,
      longitude: longitude,
      syncPending: syncPending ?? this.syncPending,
      reporterId: reporterId,
      photoUrl: photoUrl ?? this.photoUrl,
      photoPath: photoPath,
      serverId: serverId ?? this.serverId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'personName': personName,
        'age': age,
        'gender': gender,
        'description': description,
        'lastSeenPlace': lastSeenPlace,
        'lastSeenTime': lastSeenTime.toIso8601String(),
        'reporterName': reporterName,
        'reporterPhone': reporterPhone,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'syncPending': syncPending,
        'reporterId': reporterId,
        'photoUrl': photoUrl,
        'photoPath': photoPath,
        'serverId': serverId,
      };

  factory LostPersonReport.fromJson(Map<String, dynamic> json) =>
      LostPersonReport(
        id: json['id'] as String,
        type: LostReportType.values.firstWhere(
          (LostReportType t) => t.name == json['type'],
          orElse: () => LostReportType.lost,
        ),
        personName: json['personName'] as String? ?? 'Unknown',
        age: (json['age'] as num?)?.toInt() ?? 0,
        gender: json['gender'] as String? ?? 'Unknown',
        description: json['description'] as String? ?? '',
        lastSeenPlace: json['lastSeenPlace'] as String? ?? '',
        lastSeenTime:
            DateTime.tryParse(json['lastSeenTime'] as String? ?? '') ??
                DateTime.now(),
        reporterName: json['reporterName'] as String? ?? '',
        reporterPhone: json['reporterPhone'] as String? ?? '',
        status: LostReportStatus.values.firstWhere(
          (LostReportStatus s) => s.name == json['status'],
          orElse: () => LostReportStatus.active,
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        syncPending: json['syncPending'] as bool? ?? true,
        reporterId: json['reporterId'] as String?,
        photoUrl: json['photoUrl'] as String?,
        photoPath: json['photoPath'] as String?,
        serverId: json['serverId'] as String?,
      );

  /// Maps a backend record (`GET /lost-person`) onto the app model.
  factory LostPersonReport.fromApi(Map<String, dynamic> json) {
    final String serverId = json['lost_person_id'] as String? ?? '';
    final String shortId =
        serverId.length >= 8 ? serverId.substring(0, 8) : serverId;
    return LostPersonReport(
      id: 'SRV-${shortId.toUpperCase()}',
      serverId: serverId.isEmpty ? null : serverId,
      type: json['report_type'] == 'found'
          ? LostReportType.found
          : LostReportType.lost,
      personName: json['name'] as String? ?? 'Unknown',
      age: (json['age'] as num?)?.toInt() ?? 0,
      gender: json['gender'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      lastSeenPlace: json['last_seen_location'] as String? ?? '',
      lastSeenTime:
          DateTime.tryParse(json['last_seen_time'] as String? ?? '') ??
              DateTime.now(),
      reporterName: json['reporter_name'] as String? ?? 'Community report',
      reporterPhone: json['reporter_phone'] as String? ?? '',
      status: json['status'] == 'reunited'
          ? LostReportStatus.reunited
          : LostReportStatus.active,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now(),
      latitude: (json['last_seen_latitude'] as num?)?.toDouble(),
      longitude: (json['last_seen_longitude'] as num?)?.toDouble(),
      reporterId: json['reporter_id'] as String?,
      photoUrl: json['photo_url'] as String?,
      syncPending: false,
    );
  }
}
