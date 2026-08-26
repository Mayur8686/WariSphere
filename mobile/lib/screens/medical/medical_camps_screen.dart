import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../models/medical_camp.dart';
import '../../../state/camps_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_header.dart';

/// Medical camps along the wari: search, filter, call, open in maps.
class MedicalCampsScreen extends StatefulWidget {
  const MedicalCampsScreen({super.key});

  @override
  State<MedicalCampsScreen> createState() => _MedicalCampsScreenState();
}

class _MedicalCampsScreenState extends State<MedicalCampsScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Passive: only attaches distance if location permission already granted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CampsProvider>().attachDistanceIfPermitted();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openCampSheet(MedicalCamp camp) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CampDetailSheet(camp: camp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CampsProvider provider = context.watch<CampsProvider>();
    final TextTheme text = Theme.of(context).textTheme;
    final List<MedicalCamp> camps = provider.camps;

    return Scaffold(
      appBar: AppBar(title: const Text('Medical Camps')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: TextField(
                controller: _search,
                onChanged: provider.setQuery,
                decoration: const InputDecoration(
                  hintText: 'Search by halt, camp or service…',
                  prefixIcon: Icon(Icons.search_rounded),
                  suffixIcon: Icon(Icons.tune_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: <Widget>[
                  _FilterChip(
                    label: 'All camps',
                    selected: provider.filter == CampFilter.all,
                    onTap: () => provider.setFilter(CampFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Open 24×7',
                    selected: provider.filter == CampFilter.open24x7,
                    onTap: () => provider.setFilter(CampFilter.open24x7),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '3+ doctors',
                    selected: provider.filter == CampFilter.withDoctors,
                    onTap: () => provider.setFilter(CampFilter.withDoctors),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '10+ beds',
                    selected: provider.filter == CampFilter.withBeds,
                    onTap: () => provider.setFilter(CampFilter.withBeds),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${camps.length} camp(s) on the route • works offline',
                style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: provider.loading
                  ? const Center(child: CircularProgressIndicator())
                  : camps.isEmpty
                      ? const EmptyState(
                          icon: Icons.medical_services_outlined,
                          title: 'No camps match',
                          message: 'Try clearing the search or filters.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                          itemCount: camps.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext ctx, int i) => _CampCard(
                            camp: camps[i],
                            distanceKm: provider.distanceKmFromMe(camps[i]),
                            onTap: () => _openCampSheet(camps[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: selected ? AppColors.maroonDeep : AppColors.inkSoft,
      ),
    );
  }
}

class _CampCard extends StatelessWidget {
  const _CampCard({
    required this.camp,
    required this.onTap,
    this.distanceKm,
  });

  final MedicalCamp camp;
  final VoidCallback onTap;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.medical_services_rounded,
                color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        camp.name,
                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (camp.is24x7)
                      const StatusPill24x7(),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${camp.stopName} • ${camp.organization}',
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    if (distanceKm != null)
                      _MiniStat(
                        icon: Icons.near_me_rounded,
                        label: Formatters.km(distanceKm!),
                        color: AppColors.saffronDark,
                      ),
                    _MiniStat(
                      icon: Icons.person_rounded,
                      label: '${camp.doctors} doctors',
                      color: AppColors.info,
                    ),
                    _MiniStat(
                      icon: Icons.bed_rounded,
                      label: '${camp.beds} beds',
                      color: AppColors.maroon,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill24x7 extends StatelessWidget {
  const StatusPill24x7({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '24×7',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: AppColors.success,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampDetailSheet extends StatelessWidget {
  const _CampDetailSheet({required this.camp});

  final MedicalCamp camp;

  Future<void> _launch(BuildContext context, Uri uri, String fallback) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fallback)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    camp.name,
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                if (camp.is24x7) const StatusPill24x7(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${camp.organization} • ${camp.stopName}',
              style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            const SectionHeader(title: 'Services'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: camp.services
                  .map(
                    (String s) => Chip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            const SectionHeader(title: 'Capacity & timings'),
            Row(
              children: <Widget>[
                Expanded(
                  child: _CapacityTile(
                      icon: Icons.person_rounded,
                      value: '${camp.doctors}',
                      label: 'Doctors'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CapacityTile(
                      icon: Icons.bed_rounded,
                      value: '${camp.beds}',
                      label: 'Beds'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CapacityTile(
                      icon: Icons.schedule_rounded,
                      value: camp.timingsLabel.replaceAll('Open ', ''),
                      label: 'Timings'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Call camp'),
                    onPressed: camp.contact == null
                        ? null
                        : () => _launch(context, GeoUtils.telUri(camp.contact!),
                            'No contact number available'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: const Text('Directions'),
                    onPressed: () => _launch(
                      context,
                      GeoUtils.mapUri(camp.latitude, camp.longitude, label: camp.name),
                      'Could not open maps — pin: '
                      '${Formatters.latLng(camp.latitude, camp.longitude)}',
                    ),
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

class _CapacityTile extends StatelessWidget {
  const _CapacityTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.saffronDark),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
