/// The Warkari pilgrim profile. Stored locally (offline-first) in Phase 1/2;
/// synced to Firestore in Phase 3.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.age,
    required this.gender,
    required this.bloodGroup,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.homeCity,
    this.dindiName,
    required this.createdAt,
  });

  final String id; // e.g. WRI-8F3K2A – printed on the QR ID
  final String fullName;
  final String phone;
  final int age;
  final String gender;
  final String bloodGroup;
  final String emergencyContactName;
  final String emergencyContactPhone; // ICE – "In Case of Emergency"
  final String? homeCity;
  final String? dindiName; // the group/dindi the pilgrim walks with
  final DateTime createdAt;

  String get initials {
    final List<String> parts =
        fullName.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String firstChar(String s) => String.fromCharCode(s.runes.first);
    if (parts.length == 1) return firstChar(parts.first).toUpperCase();
    return (firstChar(parts.first) + firstChar(parts.last)).toUpperCase();
  }

  AppUser copyWith({
    String? id,
    String? fullName,
    String? phone,
    int? age,
    String? gender,
    String? bloodGroup,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? homeCity,
    String? dindiName,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      homeCity: homeCity ?? this.homeCity,
      dindiName: dindiName ?? this.dindiName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fullName': fullName,
        'phone': phone,
        'age': age,
        'gender': gender,
        'bloodGroup': bloodGroup,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'homeCity': homeCity,
        'dindiName': dindiName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        phone: json['phone'] as String,
        age: json['age'] as int,
        gender: json['gender'] as String,
        bloodGroup: json['bloodGroup'] as String,
        emergencyContactName: json['emergencyContactName'] as String,
        emergencyContactPhone: json['emergencyContactPhone'] as String,
        homeCity: json['homeCity'] as String?,
        dindiName: json['dindiName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// Text encoded into the pilgrim QR code. Kept short so the QR stays
  /// easy to scan even on damaged prints; full profile lives behind the ID.
  String qrPayload() =>
      'WARISATHI|$id|$fullName|BG:$bloodGroup|AGE:$age|ICE:$emergencyContactPhone';
}
