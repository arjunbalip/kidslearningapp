import 'package:flutter/material.dart';

/// Colours from the Design System (tokens.json).
class AppColors {
  AppColors._();

  static const surface100 = Color(0xFFFFF8EC); // page background
  static const surface200 = Color(0xFFFFFFFF); // cards
  static const surface300 = Color(0xFFFFEFD3); // soft panels, parent area
  static const sky100 = Color(0xFFDCEFFF); // sky backdrop
  static const ink = Color(0xFF2A2340); // all text
  static const inkMuted = Color(0xFF5E5873); // parent-area secondary text
  static const brandOrange = Color(0xFFEA580C); // Pip, main buttons
  static const lettersBlue = Color(0xFF2563EB); // Letters world
  static const numbersGreen = Color(0xFF16A34A); // Numbers world
  static const numbersGreenText = Color(0xFF15803D); // green text on cream
  static const starYellow = Color(0xFFFFC83D); // stars, rewards
  static const playPink = Color(0xFFDB2777); // one accent per screen
  static const hintAmber = Color(0xFFF59E0B); // gentle retry hint
  static const line = Color(0xFFC9C3D9); // quiet outlines
}

/// Spacing steps and the minimum tap size for children.
class AppSpace {
  AppSpace._();

  static const s2 = 8.0;
  static const s4 = 16.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const tapMin = 72.0;
}

class AppRadius {
  AppRadius._();

  static const md = 16.0;
  static const lg = 28.0;
}

/// Baloo 2 is a variable font: the weight is set through the 'wght' axis.
TextStyle baloo(
  double size, {
  int weight = 700,
  Color color = AppColors.ink,
  double? height,
}) {
  final w = weight.clamp(400, 800).toInt();
  return TextStyle(
    fontFamily: 'Baloo2',
    fontSize: size,
    color: color,
    height: height,
    fontWeight: FontWeight.values[(w ~/ 100) - 1],
    fontVariations: [FontVariation('wght', w.toDouble())],
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Baloo2',
    scaffoldBackgroundColor: AppColors.surface100,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brandOrange,
      surface: AppColors.surface100,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}
