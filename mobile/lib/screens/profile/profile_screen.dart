import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/app_user.dart';
import '../../../state/auth_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/section_header.dart';

/// Profile: identity, medical info, emergency contact, settings, logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'Your Wari ID stays on this device. You can sign in again anytime.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.login, (Route<dynamic> r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = context.watch<AuthProvider>().user;
    final TextTheme text = Theme.of(context).textTheme;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: <Widget>[
            // ---- identity card ----
            AppCard(
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.saffron,
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          user.fullName,
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          user.phone,
                          style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.saffronLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'ID ${user.id}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.saffronDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const SectionHeader(title: 'Personal details'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _Row('Age', '${user.age} yrs'),
                  const Divider(height: 1, indent: 16),
                  _Row('Gender', user.gender),
                  const Divider(height: 1, indent: 16),
                  _Row('Dindi', user.dindiName ?? '—'),
                  const Divider(height: 1, indent: 16),
                  _Row('Home', user.homeCity ?? '—'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const SectionHeader(title: 'Medical & emergency'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _Row('Blood group', user.bloodGroup),
                  const Divider(height: 1, indent: 16),
                  _Row('Emergency contact', user.emergencyContactName),
                  const Divider(height: 1, indent: 16),
                  _Row('Contact number', user.emergencyContactPhone),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const SectionHeader(title: 'Settings'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.edit_rounded,
                        color: AppColors.saffronDark),
                    title: const Text('Edit profile',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.inkSoft),
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.editProfile),
                  ),
                  const Divider(height: 1, indent: 16),
                  const ListTile(
                    leading:
                        Icon(Icons.cloud_sync_rounded, color: AppColors.info),
                    title: Text('Cloud sync (Firebase)',
                        style:
                            TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    subtitle: Text(
                        'Offline-first now — connects in Phase 3',
                        style: TextStyle(fontSize: 12)),
                    trailing: Chip(
                      label: Text('Soon',
                          style: TextStyle(fontSize: 11, color: AppColors.info)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.infoSoft,
                      side: BorderSide.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.health_and_safety_rounded,
                      size: 20, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${AppConstants.appName} v${AppConstants.appVersion} • '
                      'All your data lives on this phone.',
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sosRed,
                side: const BorderSide(color: AppColors.sosRed),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log out'),
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
