import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// WariSathi brand mark: palkhi/temple on a saffron disc.
class WariLogo extends StatelessWidget {
  const WariLogo({super.key, this.size = 96, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.saffronGradient,
            ),
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x33E85D14),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.temple_hindu_rounded,
            size: size * 0.52,
            color: Colors.white,
          ),
        ),
        if (showName) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            AppConstants.appName,
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppConstants.appTaglineMr,
            style: text.bodyMedium?.copyWith(color: AppColors.maroon),
          ),
        ],
      ],
    );
  }
}
