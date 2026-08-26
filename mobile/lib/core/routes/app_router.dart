import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/lost/lost_person_screen.dart';
import '../../screens/medical/medical_camps_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/qr/my_qr_screen.dart';
import '../../screens/route/route_screen.dart';
import '../../screens/sos/sos_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../state/auth_provider.dart';
import 'app_routes.dart';

/// Named-route table with a lightweight auth guard.
class AppRouter {
  AppRouter._();

  static const String splash = AppRoutes.splash;

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _page(const SplashScreen(), settings);
      case AppRoutes.login:
        return _page(const LoginScreen(), settings);
      case AppRoutes.register:
        return _page(const RegisterScreen(), settings);
      case AppRoutes.home:
        return _guarded(const HomeScreen(), settings);
      case AppRoutes.sos:
        return _guarded(const SosScreen(), settings);
      case AppRoutes.camps:
        return _guarded(const MedicalCampsScreen(), settings);
      case AppRoutes.lost:
        return _guarded(const LostPersonScreen(), settings);
      case AppRoutes.wariRoute:
        return _guarded(const RouteScreen(), settings);
      case AppRoutes.myQr:
        return _guarded(const MyQrScreen(), settings);
      case AppRoutes.profile:
        return _guarded(const ProfileScreen(), settings);
      case AppRoutes.editProfile:
        return _guarded(const EditProfileScreen(), settings);
      default:
        return _page(
          const Scaffold(body: Center(child: Text('Page not found'))),
          settings,
        );
    }
  }

  static MaterialPageRoute<dynamic> _page(Widget page, RouteSettings settings) =>
      MaterialPageRoute<dynamic>(builder: (_) => page, settings: settings);

  /// Protected routes require a signed-in Warkari; otherwise render login.
  static MaterialPageRoute<dynamic> _guarded(Widget page, RouteSettings settings) =>
      MaterialPageRoute<dynamic>(
        builder: (_) => RequireAuth(child: page),
        settings: settings,
      );
}

class RequireAuth extends StatelessWidget {
  const RequireAuth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool authed = context.watch<AuthProvider>().isLoggedIn;
    if (!authed) return const LoginScreen();
    return child;
  }
}
