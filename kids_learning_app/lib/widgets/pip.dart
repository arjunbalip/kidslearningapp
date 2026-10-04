import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/responsive.dart';
import '../app/theme.dart';

/// Pip the owl, the app's mascot (first concept drawing).
/// Later this becomes a Rive animation with wave, cheer and nod poses.
class Pip extends StatelessWidget {
  const Pip({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/pip.svg',
      height: height,
      fit: BoxFit.contain,
      semanticsLabel: 'Pip the owl',
    );
  }
}

/// White rounded bubble for what Pip "says" (also spoken aloud later).
class SpeechBubble extends StatelessWidget {
  const SpeechBubble(this.text, {super.key, this.fontSize});

  final String text;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final size = fontSize ?? Screen.of(context).bubbleSize;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.8, vertical: size * 0.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: baloo(size, weight: 700, height: 1.15),
      ),
    );
  }
}
