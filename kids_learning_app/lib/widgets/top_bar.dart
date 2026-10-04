import 'package:flutter/material.dart';

import 'star_counter.dart';

/// The bar at the top of child screens: [leading] on the left,
/// optional [center] in the middle (shrinks to fit), star counter on the right.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.leading, this.center});

  final Widget leading;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        const SizedBox(width: 8),
        Expanded(
          child: Center(
            child: center == null
                ? const SizedBox.shrink()
                : FittedBox(fit: BoxFit.scaleDown, child: center),
          ),
        ),
        const SizedBox(width: 8),
        const StarCounter(),
      ],
    );
  }
}
