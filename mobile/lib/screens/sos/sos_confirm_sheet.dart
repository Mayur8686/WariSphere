import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/sos_alert.dart';
import '../../../widgets/primary_button.dart';

/// Full-screen confirmation step before an SOS goes out.
/// Auto-sends after a 5-second countdown so an accidental hold can be
/// cancelled, but a real emergency doesn't need a second tap.
class SosConfirmSheet extends StatefulWidget {
  const SosConfirmSheet({
    super.key,
    required this.type,
    required this.note,
    required this.onSend,
  });

  final SosType type;
  final String? note;
  final VoidCallback onSend;

  /// Convenience launcher.
  static Future<void> show(
    BuildContext context, {
    required SosType type,
    required String? note,
    required VoidCallback onSend,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SosConfirmSheet(type: type, note: note, onSend: onSend),
    );
  }

  @override
  State<SosConfirmSheet> createState() => _SosConfirmSheetState();
}

class _SosConfirmSheetState extends State<SosConfirmSheet> {
  static const int _totalSeconds = 5;
  int _remaining = _totalSeconds;
  Timer? _timer;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining -= 1);
      if (_remaining <= 0) {
        t.cancel();
        _sendNow();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sendNow() {
    if (_sent) return;
    _sent = true;
    Navigator.of(context).pop(); // close sheet
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _remaining / _totalSeconds;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: 108,
                  height: 108,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: AppColors.saffronLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sosRed),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$_remaining',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: AppColors.sosRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Send SOS alert?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${SosAlert.typeLabel(widget.type)}\nYour GPS location will be attached automatically.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, height: 1.45),
            ),
            if (widget.note != null && widget.note!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                '"${widget.note}"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppColors.maroon,
                ),
              ),
            ],
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Send now',
              icon: Icons.campaign_rounded,
              color: AppColors.sosRed,
              onPressed: _sendNow,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel — I am safe'),
            ),
          ],
        ),
      ),
    );
  }
}
