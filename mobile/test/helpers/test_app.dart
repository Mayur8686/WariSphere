import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wari_sathi/core/di/app_bootstrap.dart';
import 'package:wari_sathi/core/services/storage_service.dart';

/// Builds the real app with the real (offline/mock) dependency graph —
/// the exact same wiring as production `main()`.
Widget buildTestApp(SharedPreferences prefs) {
  return bootstrapWariSathiApp(prefs);
}

/// Re-exported so tests can construct single providers if needed.
StorageService makeStorage(SharedPreferences prefs) => StorageService(prefs);
