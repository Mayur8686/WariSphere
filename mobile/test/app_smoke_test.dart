import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wari_sathi/screens/auth/login_screen.dart';
import 'package:wari_sathi/screens/splash/splash_screen.dart';

import 'helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots: splash restores offline session and lands on login',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestApp(prefs));

    // Splash is visible initially.
    expect(find.byType(SplashScreen), findsOneWidget);

    // Splash auto-navigates after ~1.9s. No registered user → Login.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.textContaining('Demo mode', findRichText: true), findsOneWidget);
  });
}
