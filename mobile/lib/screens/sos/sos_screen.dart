import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/sms_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/sos_alert.dart';
import '../../../state/auth_provider.dart';
import '../../../state/sos_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/status_chip.dart';
import 'sos_confirm_sheet.dart';
import 'sos_success_view.dart';

/// SOS screen: pick emergency type → hold 2s → confirm → GPS + send.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  SosType _selectedType = SosType.medical;
  final TextEditingController _note = TextEditingController();
  SosAlert? _lastSent;
  String? _locationWarning;

  @override
  void initState() {
    super.initState();
    // Offline-first drain: retry queued alerts against the backend when
    // the screen opens (e.g. alerts raised while out of coverage).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final SosProvider sos = context.read<SosProvider>();
      if (sos.pendingSyncCount > 0) sos.retrySync();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _onHoldComplete() async {
    await SosConfirmSheet.show(
      context,
      type: _selectedType,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      onSend: () => _send(),
    );
  }

  Future<void> _send() async {
    final AuthProvider auth = context.read<AuthProvider>();
    final SosProvider sos = context.read<SosProvider>();

    final SosAlert? alert = await sos.sendAlert(
      type: _selectedType,
      userId: auth.user?.id ?? 'anonymous',
      userName: auth.user?.fullName ?? 'Unknown',
      userPhone: auth.user?.phone ?? '',
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _lastSent = alert;
      _locationWarning = sos.locationWarning;
    });
    if (alert != null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SOS ${alert.id} sent — help is being routed.')),
      );
      // Offline fallback: pre-fill an SMS to the emergency contact with a
      // live Google Maps link — reaches family even with zero internet.
      final bool autoSms = (_icePhone.isNotEmpty) &&
          context.read<StorageService>().loadAutoIceSms();
      if (autoSms) {
        await _openIceSms(alert);
      }
    }
  }

  String get _icePhone =>
      context.read<AuthProvider>().user?.emergencyContactPhone ?? '';

  String get _iceName =>
      context.read<AuthProvider>().user?.emergencyContactName ?? '';

  String _iceSmsBody(SosAlert alert) {
    final AuthProvider auth = context.read<AuthProvider>();
    return SmsService.buildIceMessage(
      senderName: auth.user?.fullName ?? 'A Warkari',
      typeLabel: SosAlert.typeLabel(alert.type),
      latitude: alert.latitude,
      longitude: alert.longitude,
      accuracyMeters: alert.accuracyMeters,
    );
  }

  Future<void> _openIceSms(SosAlert alert) async {
    final bool ok = await context
        .read<SmsService>()
        .composeIceSms(phone: _icePhone, body: _iceSmsBody(alert));
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Could not open the SMS app — use the Emergency SMS card below.')),
      );
    }
  }

  Future<void> _copyIceSms(SosAlert alert) async {
    await Clipboard.setData(ClipboardData(text: _iceSmsBody(alert)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency SMS text copied')),
    );
  }

  Future<void> _resolve(SosProvider sos, String alertId) async {
    await sos.markResolved(alertId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marked as resolved — get well soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SosProvider sos = context.watch<SosProvider>();
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('SOS – Emergency Help')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: <Widget>[
            // ---- explanation banner ----
            AppCard(
              padding: const EdgeInsets.all(14),
              borderColor: AppColors.sosRed.withValues(alpha: 0.25),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.volunteer_activism_rounded,
                      color: AppColors.sosRed, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This alerts nearby volunteers, medical camps and the '
                      'control room with your GPS location.',
                      style: text.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---- emergency type ----
            Text('1. What kind of help do you need?',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SosType.values.map((SosType t) {
                final bool selected = t == _selectedType;
                return ChoiceChip(
                  label: Text(SosAlert.typeLabel(t)),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedType = t),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.maroonDeep : AppColors.inkSoft,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ---- optional note ----
            Text('2. Anything to add? (optional)',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLines: 2,
              maxLength: 140,
              decoration: const InputDecoration(
                hintText: 'e.g. "Leg injury near Yavat camp, can\'t walk"',
              ),
            ),

            // ---- hold button ----
            const SizedBox(height: 10),
            Text('3. Hold the button for 2 seconds to trigger',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Center(child: _HoldToSosButton(onConfirmed: _onHoldComplete)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                AppStrings.sosHoldHint,
                style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
            ),

            // ---- in-flight progress ----
            if (sos.isWorking) ...<Widget>[
              const SizedBox(height: 20),
              AppCard(
                child: Row(
                  children: <Widget>[
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        sos.phase == SosPhase.locating
                            ? 'Getting your GPS location…'
                            : AppStrings.sosSending,
                        style: text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ---- success ----
            if (_lastSent != null && !sos.isWorking) ...<Widget>[
              const SizedBox(height: 20),
              SosSuccessView(
                alert: _lastSent!,
                locationWarning: _locationWarning,
                iceName: _iceName,
                icePhone: _icePhone,
                smsBody: _iceSmsBody(_lastSent!),
                onSendSms:
                    _icePhone.isEmpty ? null : () => _openIceSms(_lastSent!),
                onCopySms:
                    _icePhone.isEmpty ? null : () => _copyIceSms(_lastSent!),
              ),
            ],

            // ---- history ----
            const SizedBox(height: 24),
            Text('My past alerts',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (sos.alerts.isEmpty)
              const EmptyState(
                icon: Icons.history_rounded,
                title: 'No alerts yet',
                message: 'Your SOS history will appear here — even offline.',
              )
            else
              ...sos.alerts.take(5).map(
                    (SosAlert a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AlertHistoryTile(
                        alert: a,
                        onResolve: sos.phase == SosPhase.idle
                            ? () => _resolve(sos, a.id)
                            : null,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _AlertHistoryTile extends StatelessWidget {
  const _AlertHistoryTile({required this.alert, this.onResolve});

  final SosAlert alert;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final (String label, Color color, Color soft) = switch (alert.status) {
      SosStatus.pending => ('Sending', AppColors.warning, AppColors.warningSoft),
      SosStatus.sent => ('Sent', AppColors.info, AppColors.infoSoft),
      SosStatus.acknowledged => ('Volunteer responding', AppColors.saffronDark, AppColors.saffronLight),
      SosStatus.resolved => ('Resolved', AppColors.success, AppColors.successSoft),
    };

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${alert.id} • ${SosAlert.typeLabel(alert.type)}',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              StatusChip(label: label, color: color, softBackground: soft),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${Formatters.dateTimeShort(alert.createdAt)}'
            '${alert.hasLocation ? ' • ${Formatters.latLng(alert.latitude!, alert.longitude!)}' : ''}',
            style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
          Row(
            children: <Widget>[
              if (alert.syncPending) ...<Widget>[
                const StatusChip(
                  label: AppStrings.pendingSync,
                  color: AppColors.warning,
                  softBackground: AppColors.warningSoft,
                  icon: Icons.cloud_off_rounded,
                ),
                const Spacer(),
              ] else
                const Spacer(),
              if (onResolve != null && alert.status != SosStatus.resolved)
                TextButton(
                  onPressed: onResolve,
                  child: const Text('Mark resolved'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular button that fills while held; completing the hold triggers SOS.
class _HoldToSosButton extends StatefulWidget {
  const _HoldToSosButton({required this.onConfirmed});

  final VoidCallback onConfirmed;

  @override
  State<_HoldToSosButton> createState() => _HoldToSosButtonState();
}

class _HoldToSosButtonState extends State<_HoldToSosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void initState() {
    super.initState();
    _fill.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onConfirmed();
        _fill.reset();
      }
    });
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (_) {
        HapticFeedback.mediumImpact();
        _fill.forward();
      },
      onPanUpdate: (_) {},
      onPanCancel: () => _fill.reverse(),
      onPanEnd: (_) => _fill.reverse(),
      child: AnimatedBuilder(
        animation: _fill,
        builder: (BuildContext context, _) {
          final double t = _fill.value;
          return CustomPaint(
            painter: _RingPainter(progress: t),
            child: Container(
              width: 190,
              height: 190,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.sosGradient,
                ),
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x559D0208),
                    blurRadius: 26,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.sos_rounded, color: Colors.white, size: 52),
                  const SizedBox(height: 8),
                  Text(
                    t > 0 ? '${(2000 - (t * 2000)).round()} ms' : 'HOLD 2 SEC',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const double stroke = 8;
    final Offset c = size.center(Offset.zero);
    final double radius = (size.shortestSide / 2) + 10;

    final Paint bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.sosRed.withValues(alpha: 0.18);

    canvas.drawCircle(c, radius, bg);

    if (progress > 0) {
      final Paint fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = AppColors.sosRedDark;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius),
        -3.14159 / 2, // start at top
        3.14159 * 2 * progress,
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
