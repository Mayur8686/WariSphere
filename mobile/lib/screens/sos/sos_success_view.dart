import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../models/sos_alert.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/primary_button.dart';

/// Shown right after an alert is accepted — reassurance + quick actions,
/// including the offline Emergency-SMS card for the ICE contact.
class SosSuccessView extends StatelessWidget {
  const SosSuccessView({
    super.key,
    required this.alert,
    this.locationWarning,
    this.iceName = '',
    this.icePhone = '',
    this.smsBody = '',
    this.onSendSms,
    this.onCopySms,
  });

  final SosAlert alert;
  final String? locationWarning;
  final String iceName;
  final String icePhone;
  final String smsBody;
  final VoidCallback? onSendSms;
  final VoidCallback? onCopySms;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool isWeb = kIsWeb;
    return AppCard(
      borderColor: AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.successSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'SOS alert sent!',
                      style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900, color: AppColors.success),
                    ),
                    Text(
                      'ID ${alert.id} • ${Formatters.timeOnly(alert.createdAt)}',
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _Row(
            icon: Icons.medical_information_outlined,
            label: SosAlert.typeLabel(alert.type),
          ),
          if (alert.hasLocation)
            _Row(
              icon: Icons.location_on_outlined,
              label:
                  '${Formatters.latLng(alert.latitude!, alert.longitude!)}'
                  '${_accuracyLabel()}',
            )
          else
            _Row(
              icon: Icons.location_off_rounded,
              label: locationWarning ?? 'Location unavailable',
              color: AppColors.warning,
            ),
          _Row(
            icon: alert.syncPending
                ? Icons.cloud_upload_outlined
                : Icons.cloud_done_outlined,
            label: alert.syncPending
                ? 'Saved on this phone — will sync to the control room '
                    'automatically when the server is reachable'
                : 'Synced with control room ✓',
            color: alert.syncPending ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(height: 14),
          if (!isWeb)
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Call 112'),
                    onPressed: () => _launch(context,
                        GeoUtils.telUri(AppConstants.emergencyNumber)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.local_hospital_rounded, size: 18),
                    label: const Text('Call 108'),
                    onPressed: () => _launch(context,
                        GeoUtils.telUri(AppConstants.ambulanceNumber)),
                  ),
                ),
              ],
            )
          else
            const Text(
              'Dial 112 / 108 from a phone — calling is available in the mobile app.',
              style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          if (alert.hasLocation) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text('Open in maps'),
                    onPressed: () => _launch(
                      context,
                      GeoUtils.mapUri(alert.latitude!, alert.longitude!,
                          label: 'SOS ${alert.id}'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy location'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: Formatters.latLng(alert.latitude!, alert.longitude!)));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coordinates copied')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],

          // ---- Emergency SMS fallback (works with zero internet) ----
          if (icePhone.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.sms_rounded,
                          size: 18, color: AppColors.warning),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Emergency SMS — reaches family without internet',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To: ${iceName.isEmpty ? icePhone : '$iceName • $icePhone'}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      smsBody,
                      style: const TextStyle(fontSize: 11.5, height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      if (!isWeb) ...<Widget>[
                        Expanded(
                          child: PrimaryButton(
                            label: 'Send SMS',
                            icon: Icons.send_rounded,
                            color: AppColors.saffron,
                            onPressed: onSendSms,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: Text(isWeb ? 'Copy text' : 'Copy'),
                          onPressed: onCopySms,
                        ),
                      ),
                    ],
                  ),
                  if (isWeb) ...<Widget>[
                    const SizedBox(height: 6),
                    const Text(
                      'Desktop browser detected — sending works from the '
                      'Android app. Copy the text to share it manually.',
                      style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// `±12 m` normally; desktop browsers fake GPS with huge radii — show a
  /// friendlier label instead of "±1000000 m".
  String _accuracyLabel() {
    final double? acc = alert.accuracyMeters;
    if (acc == null) return '';
    if (acc > 50000) return '  (coarse location)';
    return '  (±${acc.round()} m)';
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: color ?? AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
