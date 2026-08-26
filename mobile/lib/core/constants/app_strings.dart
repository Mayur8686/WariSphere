/// Central place for user-facing strings.
///
/// English is primary with Marathi subtitles on key surfaces (Warkari
/// pilgrims are Marathi-first). Phase 3+ can move this to proper ARB
/// localisation (flutter_localizations) without touching screens.
class AppStrings {
  AppStrings._();

  // ---- Splash / auth ----
  static const String splashTaglineMr = 'सुरक्षित वारी, निश्चिंत यात्रा';
  static const String splashTaglineEn = 'Safe Wari, Worry-free Yatra';
  static const String loginTitle = 'Welcome back';
  static const String loginSubtitleMr = 'पुन्हा स्वागत आहे';
  static const String registerTitle = 'Create your Wari ID';
  static const String registerSubtitleMr = 'तुमचे वारी आयडी तयार करा';

  // ---- Home ----
  static const String greetingMr = 'जय हरी 🙏';
  static const String homeTagline = 'Wari 2026 • Dehu–Alandi to Pandharpur';

  // ---- Features ----
  static const String sosTitle = 'SOS – Emergency Help';
  static const String sosMr = 'आपत्कालीन मदत';
  static const String campsTitle = 'Medical Camps';
  static const String campsMr = 'वैद्यकीय शिबिरे';
  static const String lostTitle = 'Lost & Found';
  static const String lostMr = 'गहाळ व्यक्ती';
  static const String routeTitle = 'Wari Route';
  static const String routeMr = 'वारीचा मार्ग';
  static const String qrTitle = 'My QR ID';
  static const String qrMr = 'माझे क्यूआर आयडी';
  static const String profileTitle = 'Profile';
  static const String profileMr = 'प्रोफाइल';

  // ---- SOS ----
  static const String sosHoldHint = 'Hold the button for 2 seconds';
  static const String sosConfirmTitle = 'Send SOS alert?';
  static const String sosSending = 'Getting your GPS location and sending the alert…';
  static const String sosSentTitle = 'SOS alert sent!';
  static const String sosOfflineNote =
      'Alert is saved on your phone and queued — it will sync the moment you have network (offline-first).';

  // ---- Offline ----
  static const String offlineBadge = 'Offline mode';
  static const String pendingSync = 'pending sync';
}
