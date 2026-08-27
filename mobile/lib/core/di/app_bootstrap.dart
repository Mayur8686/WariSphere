import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../state/auth_provider.dart';
import '../../state/camps_provider.dart';
import '../../state/lost_provider.dart';
import '../../state/route_provider.dart';
import '../../state/sos_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/data_repository.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

/// Dependency wiring shared by `main()` and widget tests.
Widget bootstrapWariSathiApp(SharedPreferences prefs) {
  final StorageService storage = StorageService(prefs);

  return MultiProvider(
    providers: [
      // Local storage
      Provider<StorageService>.value(value: storage),

      // Authentication
      Provider<AuthService>(
        create: (_) => MockAuthService(storage),
      ),

      // GPS
      Provider<LocationService>(
        create: (_) => const LocationService(),
      ),

      // FastAPI
      Provider<ApiService>(
        create: (_) => ApiService(),
      ),

      // Data repository
      Provider<DataRepository>(
        create: (BuildContext ctx) => DataRepository(
          storage: storage,
          api: ctx.read<ApiService>(),
        ),
      ),

      // Notifications
      Provider<NotificationService>(
        create: (_) => StubNotificationService(),
      ),

      // Auth state
      ChangeNotifierProvider(
        create: (BuildContext ctx) => AuthProvider(
          authService: ctx.read<AuthService>(),
          storage: storage,
        )..restore(),
      ),

      // SOS state
      ChangeNotifierProvider(
        create: (BuildContext ctx) => SosProvider(
          repository: ctx.read<DataRepository>(),
          location: ctx.read<LocationService>(),
          notifications: ctx.read<NotificationService>(),
        )..loadHistory(),
      ),

      // Medical camps
      ChangeNotifierProvider(
        create: (BuildContext ctx) => CampsProvider(
          repository: ctx.read<DataRepository>(),
          location: ctx.read<LocationService>(),
        )..load(),
      ),

      // Lost person
      ChangeNotifierProvider(
        create: (BuildContext ctx) => LostProvider(
          repository: ctx.read<DataRepository>(),
        )..load(),
      ),

      // Wari route
      ChangeNotifierProvider(
        create: (BuildContext ctx) => RouteProvider(
          repository: ctx.read<DataRepository>(),
        )..load(),
      ),
    ],
    child: const WariSathiApp(),
  );
}