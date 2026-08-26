import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/app_user.dart';
import '../../../state/auth_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/section_header.dart';

/// "My QR ID": scannable pilgrim ID for volunteers & camp help desks.
class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  bool _highContrast = true;

  @override
  Widget build(BuildContext context) {
    final AppUser? user = context.watch<AuthProvider>().user;
    final TextTheme text = Theme.of(context).textTheme;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String payload = user.qrPayload();
    final Color qrColor = _highContrast ? Colors.black : AppColors.maroonDeep;

    return Scaffold(
      appBar: AppBar(title: const Text('My QR ID')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: <Widget>[
            // ---- QR card ----
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.border),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              gradient:
                                  LinearGradient(colors: AppColors.saffronGradient),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.temple_hindu_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'WariSathi ID',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        user.id,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: AppColors.saffronDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 230,
                      backgroundColor: Colors.white,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: qrColor,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: qrColor,
                      ),
                      errorStateBuilder: (BuildContext c, Object? err) {
                        return const SizedBox(
                          width: 230,
                          height: 230,
                          child: Center(
                            child: Text('Could not build QR'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.fullName,
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  if (user.dindiName != null && user.dindiName!.isNotEmpty)
                    Text(
                      user.dindiName!,
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---- details volunteers rely on ----
            const SectionHeader(title: 'Scanned details'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _InfoRow(
                      icon: Icons.phone_android_rounded,
                      label: 'Mobile',
                      value: user.phone),
                  const Divider(height: 1, indent: 56),
                  _InfoRow(
                      icon: Icons.bloodtype_rounded,
                      label: 'Blood group',
                      value: user.bloodGroup),
                  const Divider(height: 1, indent: 56),
                  _InfoRow(
                      icon: Icons.contact_emergency_outlined,
                      label: 'Emergency contact',
                      value:
                          '${user.emergencyContactName} • ${user.emergencyContactPhone}'),
                  const Divider(height: 1, indent: 56),
                  _InfoRow(
                      icon: Icons.home_outlined,
                      label: 'Home',
                      value: user.homeCity ?? '—'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text(
                'High-contrast QR',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              subtitle: const Text(
                'Easier to scan on older phones & in sunlight',
                style: TextStyle(fontSize: 12),
              ),
              value: _highContrast,
              activeThumbColor: AppColors.saffron,
              onChanged: (bool v) => setState(() => _highContrast = v),
            ),

            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy ID payload'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: payload));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ID payload copied')),
                );
              },
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.wifi_off_rounded,
                      size: 20, color: AppColors.info),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Works fully offline. Volunteers scan this to identify you '
                      'and call your emergency contact — no internet needed on '
                      'your phone. (${AppStrings.offlineBadge})',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.saffronDark),
          const SizedBox(width: 14),
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
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
