import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Offline-first: everything below works with zero network.
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(bootstrapWariSathiApp(prefs));
}
