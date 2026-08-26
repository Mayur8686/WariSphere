import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../models/sos_alert.dart';
import '../../../widgets/app_card.dart';

/// Shown right after an alert is accepted — reassurance + quick actions.
class SosSuccessView extends StatelessWidget {
  const SosSuccessView({super.key, required this.alert, this.locationWarning});

  final SosAlert alert;
  final String? locationWarning;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
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
                  '${alert.accuracyMeters != null ? '  (±${alert.accuracyMeters!.round()} m)' : ''}',
            )
          else
            _Row(
              icon: Icons.location_off_rounded,
              label: locationWarning ?? 'Location unavailable',
              color: AppColors.warning,
            ),
          const _Row(
            icon: Icons.cloud_upload_outlined,
            label: 'Queued for sync with control room (offline-first)',
            color: AppColors.info,
          ),
          const SizedBox(height: 14),
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
        ],
      ),
    );
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
