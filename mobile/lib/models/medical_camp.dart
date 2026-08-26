/// A medical camp set up along the Wari route.
///
/// Phase 1/2: seeded sample data cached on-device.
/// Phase 3: served from Firestore (admins maintain it), cached for offline use.
class MedicalCamp {
  const MedicalCamp({
    required this.id,
    required this.name,
    required this.organization,
    required this.stopName,
    required this.latitude,
    required this.longitude,
    required this.services,
    required this.doctors,
    required this.beds,
    required this.openFrom,
    required this.openTo,
    required this.is24x7,
    this.contact,
  });

  final String id;
  final String name;
  final String organization;
  final String stopName; // halt on the Wari route
  final double latitude;
  final double longitude;
  final List<String> services;
  final int doctors;
  final int beds;
  final String openFrom; // "06:00"
  final String openTo; // "22:00"
  final bool is24x7;
  final String? contact;

  String get timingsLabel => is24x7 ? 'Open 24×7' : '$openFrom – $openTo';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'organization': organization,
        'stopName': stopName,
        'latitude': latitude,
        'longitude': longitude,
        'services': services,
        'doctors': doctors,
        'beds': beds,
        'openFrom': openFrom,
        'openTo': openTo,
        'is24x7': is24x7,
        'contact': contact,
      };

  factory MedicalCamp.fromJson(Map<String, dynamic> json) => MedicalCamp(
        id: json['id'] as String,
        name: json['name'] as String,
        organization: json['organization'] as String,
        stopName: json['stopName'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        services: (json['services'] as List<dynamic>).cast<String>(),
        doctors: json['doctors'] as int,
        beds: json['beds'] as int,
        openFrom: json['openFrom'] as String,
        openTo: json['openTo'] as String,
        is24x7: json['is24x7'] as bool,
        contact: json['contact'] as String?,
      );
}
