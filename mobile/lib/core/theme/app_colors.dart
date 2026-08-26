import 'package:flutter/material.dart';

/// WariSathi palette — bhagwa (saffron) of the palkhi, deep maroon and
/// warm cream, with a strong SOS red reserved for emergencies.
class AppColors {
  AppColors._();

  // Brand
  static const Color saffron = Color(0xFFF26B21);
  static const Color saffronDark = Color(0xFFD9531E);
  static const Color saffronLight = Color(0xFFFFE8D6);
  static const Color maroon = Color(0xFF7A1F1F);
  static const Color maroonDeep = Color(0xFF4A1010);

  // Surfaces
  static const Color cream = Color(0xFFFFF8EF);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFF0DECB);

  // Text
  static const Color ink = Color(0xFF2B1B12);
  static const Color inkSoft = Color(0xFF8A7161);

  // Semantic
  static const Color sosRed = Color(0xFFD62828);
  static const Color sosRedDark = Color(0xFF9D0208);
  static const Color success = Color(0xFF2E7D32);
  static const Color successSoft = Color(0xFFE3F2E4);
  static const Color warning = Color(0xFFB26A00);
  static const Color warningSoft = Color(0xFFFFF1DC);
  static const Color info = Color(0xFF1565C0);
  static const Color infoSoft = Color(0xFFE3EEFB);

  // Gradients
  static const List<Color> saffronGradient = <Color>[
    Color(0xFFF79043),
    Color(0xFFE85D14),
  ];
  static const List<Color> sosGradient = <Color>[
    Color(0xFFE5383B),
    Color(0xFF9D0208),
  ];
  static const List<Color> headerGradient = <Color>[
    maroon,
    maroonDeep,
  ];
}
