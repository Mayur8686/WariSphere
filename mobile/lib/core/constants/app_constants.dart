/// App-wide constants: identity, emergency numbers, demo data.
class AppConstants {
  AppConstants._();

  static const String appName = 'WariSathi';
  static const String appTaglineMr = 'वारकरांचा सोबती';
  static const String appTaglineEn = 'Safe Wari, Worry-free Yatra';
  static const String appVersion = '0.1.0';

  /// Prefix embedded in every QR payload so volunteer scanners can
  /// recognise a WariSathi pilgrim ID instantly.
  static const String qrPayloadPrefix = 'WARISATHI|';

  // ---- National emergency numbers (India) ----
  static const String emergencyNumber = '112';
  static const String ambulanceNumber = '108';
  static const String womenHelpline = '1091';
  static const String childHelpline = '1098';
  static const String medicalHelpline = '104';

  // ---- Demo credentials used by MockAuthService (Phase 1/2) ----
  static const String demoPhone = '9876543210';
  static const String demoPassword = 'wari123';

  static const List<String> bloodGroups = <String>[
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  static const List<String> genders = <String>[
    'Male', 'Female', 'Other',
  ];
}
