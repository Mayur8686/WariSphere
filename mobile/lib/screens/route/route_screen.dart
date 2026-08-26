import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/wari_route.dart';
import '../../../state/route_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/status_chip.dart';

/// Wari route: stop-by-stop timeline with a self-set "I am here" marker
/// (offline-friendly — GPS is unreliable inside crowds).
class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final RouteProvider provider = context.watch<RouteProvider>();
    final WariRoute? route = provider.route;

    return Scaffold(
      appBar: AppBar(title: const Text('Wari Route')),
      body: SafeArea(
        child: provider.loading || route == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: <Widget>[
                  _RouteHeader(route: route),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.waving_hand_rounded,
                            size: 20, color: AppColors.saffronDark),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tap any halt and choose "Set as my location" to keep '
                            'your dindi oriented — even without network.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SectionHeader(title: 'Halts & schedule'),
                  ..._buildTimeline(context, route, provider),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildTimeline(
    BuildContext context,
    WariRoute route,
    RouteProvider provider,
  ) {
    final List<Widget> widgets = <Widget>[];
    for (int i = 0; i < route.stops.length; i++) {
      final bool isLast = i == route.stops.length - 1;
      widgets.add(
        _StopTile(
          stop: route.stops[i],
          isLast: isLast,
          isCurrent: provider.currentStopId == route.stops[i].id,
          onSetCurrent: () => _confirmSetCurrent(context, provider, route.stops[i]),
        ),
      );
    }
    return widgets;
  }

  Future<void> _confirmSetCurrent(
    BuildContext context,
    RouteProvider provider,
    RouteStop stop,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                stop.name,
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                stop.description,
                style: const TextStyle(color: AppColors.inkSoft, height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Set as my current location'),
                onPressed: () async {
                  await provider.setCurrentStop(stop.id);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Location set to ${stop.name}')),
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({required this.route});

  final WariRoute route;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.headerGradient),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.route_rounded, color: Color(0xFFFFC08A), size: 20),
              SizedBox(width: 8),
              Text(
                'Ashadhi Wari',
                style: TextStyle(
                  color: Color(0xFFFFC08A),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            route.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _Stat(value: '${route.totalKm.round()}', label: 'km total'),
              const SizedBox(width: 22),
              _Stat(value: '${route.totalDays}', label: 'days'),
              const SizedBox(width: 22),
              _Stat(value: '${route.stops.length}', label: 'major halts'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            route.subtitle,
            style: const TextStyle(
              color: Color(0xFFE8CDCD),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFE8CDCD), fontSize: 11),
        ),
      ],
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.stop,
    required this.isLast,
    required this.isCurrent,
    required this.onSetCurrent,
  });

  final RouteStop stop;
  final bool isLast;
  final bool isCurrent;
  final VoidCallback onSetCurrent;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // timeline rail
          Column(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent ? AppColors.saffron : Colors.white,
                  border: Border.all(
                    color: isCurrent ? AppColors.saffronDark : AppColors.border,
                    width: 2,
                  ),
                  boxShadow: isCurrent
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x44E85D14),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: isCurrent
                      ? const Icon(Icons.my_location_rounded,
                          color: Colors.white, size: 16)
                      : Text(
                          '${stop.day}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.inkSoft,
                          ),
                        ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.border),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: AppCard(
                onTap: onSetCurrent,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            stop.name,
                            style: text.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (isCurrent)
                          const StatusChip(
                            label: 'I am here',
                            color: AppColors.saffronDark,
                            softBackground: AppColors.saffronLight,
                            icon: Icons.place_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stop.dateLabel} • ${Formatters.km(stop.distanceFromStartKm)} from start',
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stop.description,
                      style: text.bodySmall?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
