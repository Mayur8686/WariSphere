/// Contract for notifying users (volunteer/admin pushes).
abstract class NotificationService {
  Future<void> init();

  /// Called when a local event should produce a notification-like feedback.
  Future<void> showLocal({required String title, required String body});
}

/// Phase 1/2 stub: logs locally, no OS notification yet.
///
/// TODO(Phase 3): replace with `FcmNotificationService` —
///  - `firebase_messaging` foreground/background handlers
///  - topic `wari-sos` fan-out to nearby volunteers & admin console
///  - local notifications via `flutter_local_notifications` when a
///    teammate's SOS or a "person found" update arrives.
class StubNotificationService implements NotificationService {
  final List<String> log = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> showLocal({required String title, required String body}) async {
    log.add('$title :: $body');
  }
}
