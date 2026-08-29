/// A WariSathi SOS alert.
///
/// Lifecycle (offline-first): created on-device -> [SosStatus.sent] once the
/// (mock) server acknowledges. In Phase 3 this becomes a Firestore document +
/// an FCM fan-out to nearby volunteers/admins.
enum SosType { medical, accident, safety, lostCompanion, other }

enum SosStatus { pending, sent, acknowledged, resolved }

class SosAlert {
  const SosAlert({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.type,
    required this.status,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.note,
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.syncPending = true,
  });

  final String id; // e.g. SOS-LX2C4A
  final String userId;
  final String userName;
  final String userPhone;
  final SosType type;
  final SosStatus status;
  final DateTime createdAt;

  /// ICE (In Case of Emergency) contact from the pilgrim's profile. The
  /// backend SMS gateway texts this number (plus the control-room numbers)
  /// automatically; empty when no contact is registered.
  final String emergencyContactName;
  final String emergencyContactPhone;

  /// Null when GPS was unavailable — alert still goes out with last-known
  /// or no location; Phase 3 backend can enrich from cell info.
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? note;

  /// True until the record is confirmed synced to the backend (always true
  /// in the Phase 1/2 mock).
  final bool syncPending;

  bool get hasLocation => latitude != null && longitude != null;

  SosAlert copyWith({
    SosStatus? status,
    bool? syncPending,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    return SosAlert(
      id: id,
      userId: userId,
      userName: userName,
      userPhone: userPhone,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      note: note,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      syncPending: syncPending ?? this.syncPending,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'type': type.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'note': note,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'syncPending': syncPending,
      };

  factory SosAlert.fromJson(Map<String, dynamic> json) => SosAlert(
        id: json['id'] as String,
        userId: json['userId'] as String,
        userName: json['userName'] as String? ?? '',
        userPhone: json['userPhone'] as String? ?? '',
        type: SosType.values.firstWhere(
          (SosType t) => t.name == json['type'],
          orElse: () => SosType.other,
        ),
        status: SosStatus.values.firstWhere(
          (SosStatus s) => s.name == json['status'],
          orElse: () => SosStatus.pending,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
        note: json['note'] as String?,
        emergencyContactName: json['emergencyContactName'] as String? ?? '',
        emergencyContactPhone: json['emergencyContactPhone'] as String? ?? '',
        syncPending: json['syncPending'] as bool? ?? true,
      );

  static String typeLabel(SosType t) => switch (t) {
        SosType.medical => 'Medical emergency',
        SosType.accident => 'Accident / injury',
        SosType.safety => 'Personal safety',
        SosType.lostCompanion => 'Lost companion',
        SosType.other => 'Other help',
      };
}
