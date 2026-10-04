import 'package:flutter/widgets.dart';

/// Screen-size rules so every screen works on phones and tablets,
/// in portrait and landscape.
///
/// Usage: `final s = Screen.of(context);` then `s.tap`, `s.pad`, `s.isPortrait`.
class Screen {
  const Screen._(this.size);

  final Size size;

  static Screen of(BuildContext context) => Screen._(MediaQuery.sizeOf(context));

  double get width => size.width;
  double get height => size.height;
  double get shortest => size.shortestSide;

  bool get isPortrait => size.height > size.width;

  /// Tablets (and desktop browsers) have a shortest side of 600 or more.
  bool get isTablet => shortest >= 600;

  /// Short landscape phone: very little vertical room.
  bool get isShort => size.height < 480;

  /// Outer padding of a screen.
  double get pad => isTablet ? 24 : 12;

  /// Gap between big blocks.
  double get gap => isTablet ? 24 : 12;

  /// Size of buttons a child taps (back, next, replay).
  double get tap => isTablet ? 80 : 60;

  /// Size of grown-up controls (gear, close).
  double get smallTap => isTablet ? 56 : 48;

  /// Text sizes that follow the screen.
  double get titleSize => isTablet ? 44 : 30;
  double get labelSize => isTablet ? 32 : 24;
  double get bubbleSize => isTablet ? 24 : 18;
}
