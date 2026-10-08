import 'package:flutter/material.dart';

import '../core/audio/audio_service.dart';

/// Squash-and-bounce on tap, as the Design System asks for every tap,
/// with a soft tap sound.
class Bouncy extends StatefulWidget {
  const Bouncy({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<Bouncy> {
  bool _down = false;

  void _set(bool value) {
    if (widget.onTap == null || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              AudioService.instance.effect(Sfx.tap);
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
