import 'package:flutter/material.dart';

import '../app/responsive.dart';
import '../app/theme.dart';
import 'bouncy.dart';

/// Big round button used for back, next, previous and replay.
///
/// [filled] = solid colour with a white icon; otherwise white with a
/// coloured ring. A null [onPressed] shows the button faded and inactive.
/// Without a [size], it uses the child tap size for the current screen.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color = AppColors.lettersBlue,
    this.filled = false,
    this.size,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color color;
  final bool filled;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final d = size ?? Screen.of(context).tap;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Bouncy(
          onTap: onPressed,
          child: Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? color : Colors.white,
              border: filled ? null : Border.all(color: color, width: 3),
            ),
            child: Icon(
              icon,
              size: d * 0.5,
              color: filled ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
