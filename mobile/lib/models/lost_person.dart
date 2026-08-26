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

  /// True until synced with the backend (always true in the mock).
  final bool syncPending;

  LostPersonReport copyWith({LostReportStatus? status}) {
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
      syncPending: syncPending,
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
      };

  factory LostPersonReport.fromJson(Map<String, dynamic> json) =>
      LostPersonReport(
        id: json['id'] as String,
        type: LostReportType.values.firstWhere(
          (LostReportType t) => t.name == json['type'],
          orElse: () => LostReportType.lost,
        ),
        personName: json['personName'] as String,
        age: json['age'] as int,
        gender: json['gender'] as String,
        description: json['description'] as String,
        lastSeenPlace: json['lastSeenPlace'] as String,
        lastSeenTime: DateTime.parse(json['lastSeenTime'] as String),
        reporterName: json['reporterName'] as String,
        reporterPhone: json['reporterPhone'] as String,
        status: LostReportStatus.values.firstWhere(
          (LostReportStatus s) => s.name == json['status'],
          orElse: () => LostReportStatus.active,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        syncPending: json['syncPending'] as bool? ?? true,
      );
}
