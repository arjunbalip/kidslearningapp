import 'package:flutter/material.dart';

import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/progress/stars.dart';

/// Yellow pill showing how many stars the child has.
class StarCounter extends StatelessWidget {
  const StarCounter({super.key});

  @override
  Widget build(BuildContext context) {
    final h = Screen.of(context).smallTap;
    return ValueListenableBuilder<int>(
      valueListenable: Stars.count,
      builder: (context, stars, _) => Semantics(
        label: '$stars stars',
        child: Container(
          height: h,
          padding: EdgeInsets.only(left: h * 0.2, right: h * 0.36),
          decoration: BoxDecoration(
            color: AppColors.starYellow,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: h * 0.66, color: Colors.white),
              SizedBox(width: h * 0.1),
              Text('$stars', style: baloo(h * 0.46, weight: 800)),
            ],
          ),
        ),
      ),
    );
  }
}
