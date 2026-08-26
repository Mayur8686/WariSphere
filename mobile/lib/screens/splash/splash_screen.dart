import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/auth_provider.dart';
import '../../../widgets/wari_logo.dart';

/// Splash → restore offline session → Home or Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().restore();
    });
    Future<void>.delayed(const Duration(milliseconds: 1900), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    final bool authed = context.read<AuthProvider>().isLoggedIn;
    Navigator.pushNamedAndRemoveUntil(
      context,
      authed ? AppRoutes.home : AppRoutes.login,
      (Route<dynamic> r) => false,
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[AppColors.cream, AppColors.saffronLight],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Spacer(flex: 3),
            FadeTransition(
              opacity: CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeOutBack),
                ),
                child: const WariLogo(size: 110),
              ),
            ),
            const Spacer(flex: 2),
            Text(
              AppStrings.splashTaglineMr,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.maroon,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.splashTaglineEn,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: 36),
            const Text(
              '${AppConstants.appName} v${AppConstants.appVersion}',
              style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
