import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../state/auth_provider.dart';
import '../../state/camps_provider.dart';
import '../../state/lost_provider.dart';
import '../../state/route_provider.dart';
import '../../state/sos_provider.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/data_repository.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/sms_service.dart';
import '../services/storage_service.dart';

/// Dependency wiring shared by `main()` and widget tests.
///
/// TODO(Phase 3): swap the mock implementations here —
///   MockAuthService        -> FirebaseAuthService
///   StubNotificationService -> FcmNotificationService
/// and register `FirebaseFirestore`-backed repository.
Widget bootstrapWariSathiApp(SharedPreferences prefs) {
  final StorageService storage = StorageService(prefs);

  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      Provider<AuthService>(create: (_) => MockAuthService(storage)),
      Provider<LocationService>(create: (_) => const LocationService()),
      Provider<ApiClient>(create: (_) => const ApiClient()),
      Provider<DataRepository>(
        create: (BuildContext ctx) => DataRepository(
          storage: storage,
          apiClient: ctx.read<ApiClient>(),
        ),
      ),
      Provider<NotificationService>(create: (_) => StubNotificationService()),
      Provider<SmsService>(create: (_) => const SmsService()),
      ChangeNotifierProvider(
        create: (BuildContext ctx) => AuthProvider(
          authService: ctx.read<AuthService>(),
          storage: storage,
        )..restore(),
      ),
      ChangeNotifierProvider(
        create: (BuildContext ctx) => SosProvider(
          repository: ctx.read<DataRepository>(),
          location: ctx.read<LocationService>(),
          notifications: ctx.read<NotificationService>(),
        )..loadHistory(),
      ),
      ChangeNotifierProvider(
        create: (BuildContext ctx) =>
            CampsProvider(repository: ctx.read<DataRepository>(), location: ctx.read<LocationService>())
              ..load(),
      ),
      ChangeNotifierProvider(
        create: (BuildContext ctx) => LostProvider(repository: ctx.read<DataRepository>())..load(),
      ),
      ChangeNotifierProvider(
        create: (BuildContext ctx) => RouteProvider(repository: ctx.read<DataRepository>())..load(),
      ),
    ],
    child: const WariSathiApp(),
  );
}
