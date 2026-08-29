// Basic smoke test: the real app (with the real offline/mock dependency
// graph, exactly as production `main()` wires it) builds and renders.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('app boots without errors', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestApp(prefs));

    // Give the providers time to finish their startup work (offline caches,
    // fake fetches, best-effort backend sync) so no Timer is left pending
    // when the test ends — same pattern as app_smoke_test.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });
}