import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../models/app_user.dart';
import '../../../state/auth_provider.dart';
import '../../../state/sos_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/feature_card.dart';

/// Warkari dashboard: SOS + the five support features + helpline strip.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _call(BuildContext context, String number) async {
    // Desktop browsers have no dialer: show the number with a copy button.
    if (kIsWeb) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: Text('Call $number'),
          content: const Text(
            'Dialing needs the mobile app — on a laptop, call from your '
            'phone using this number.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: number));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$number copied')),
                );
              },
              child: const Text('Copy number'),
            ),
          ],
        ),
      );
      return;
    }
    final Uri uri = GeoUtils.telUri(number);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dial $number — please dial manually.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = context.watch<AuthProvider>().user;
    final int pendingSync = context.select<SosProvider, int>((SosProvider p) => p.pendingSyncCount);
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: AppColors.saffronGradient),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.temple_hindu_rounded,
                  size: 19, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(
              AppConstants.appName,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: <Widget>[
          if (pendingSync > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Tooltip(
                  message: '$pendingSync record(s) will sync when online',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(Icons.cloud_upload_outlined,
                            size: 14, color: AppColors.warning),
                        SizedBox(width: 5),
                        Text(
                          AppStrings.offlineBadge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: AppStrings.profileTitle,
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.maroon,
              child: Text(
                user?.initials ?? '?',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: <Widget>[
            _GreetingHeader(name: user?.fullName ?? 'Warkari'),
            const SizedBox(height: 18),

            // ---------- SOS hero ----------
            _SosHero(
              onTap: () => Navigator.pushNamed(context, AppRoutes.sos),
            ),
            const SizedBox(height: 18),

            // ---------- Feature grid ----------
            Row(
              children: <Widget>[
                Text(
                  'Everything on the route',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.28,
              children: <Widget>[
                FeatureCard(
                  title: AppStrings.campsTitle,
                  subtitleMr: AppStrings.campsMr,
                  icon: Icons.medical_services_rounded,
                  color: AppColors.success,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.camps),
                ),
                FeatureCard(
                  title: AppStrings.lostTitle,
                  subtitleMr: AppStrings.lostMr,
                  icon: Icons.person_search_rounded,
                  color: AppColors.info,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.lost),
                ),
                FeatureCard(
                  title: AppStrings.routeTitle,
                  subtitleMr: AppStrings.routeMr,
                  icon: Icons.route_rounded,
                  color: AppColors.saffron,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.wariRoute),
                ),
                FeatureCard(
                  title: AppStrings.qrTitle,
                  subtitleMr: AppStrings.qrMr,
                  icon: Icons.qr_code_2_rounded,
                  color: AppColors.maroon,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.myQr),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppCard(
              onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.maroon.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_circle_rounded,
                        color: AppColors.maroon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppStrings.profileTitle,
                          style: text.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          user?.phone ?? '',
                          style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ---------- Helpline strip ----------
            Row(
              children: <Widget>[
                Expanded(
                  child: _HelplineTile(
                    label: 'Emergency\n112',
                    icon: Icons.emergency_rounded,
                    color: AppColors.sosRed,
                    onTap: () => _call(context, AppConstants.emergencyNumber),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HelplineTile(
                    label: 'Ambulance\n108',
                    icon: Icons.local_hospital_rounded,
                    color: AppColors.success,
                    onTap: () => _call(context, AppConstants.ambulanceNumber),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HelplineTile(
                    label: 'Women\n1091',
                    icon: Icons.support_agent_rounded,
                    color: AppColors.info,
                    onTap: () => _call(context, AppConstants.womenHelpline),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final String firstName = name.split(' ').first;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.headerGradient),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.greetingMr,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '$firstName • ${DateFormat('EEEE, d MMM').format(DateTime.now())}',
            style: const TextStyle(color: Color(0xFFEBD9D9), fontSize: 13.5),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              AppStrings.homeTagline,
              style: TextStyle(
                color: Color(0xFFFFE0B8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SosHero extends StatelessWidget {
  const _SosHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.sosGradient),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x339D0208),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sos_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Need urgent help?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'One tap alerts volunteers & sends your GPS location',
                      style: TextStyle(color: Color(0xFFFFD9D9), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelplineTile extends StatelessWidget {
  const _HelplineTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: <Widget>[
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
