import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/progress/stars.dart';
import '../../widgets/bouncy.dart';
import '../../widgets/pip.dart';
import '../../widgets/round_icon_button.dart';

/// Screen 6: celebration after an activity. Adds one star.
/// "Play again" goes back to the world; "Next" goes home.
/// Portrait: star on top, words and buttons below. Landscape: side by side.
class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key, required this.next});

  final String next;

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    // Add the star after the first frame, so star counters elsewhere are
    // not asked to rebuild while this screen is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) => Stars.add());
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);
    final scale = CurvedAnimation(parent: _pop, curve: Curves.elasticOut);

    final star = ScaleTransition(
      scale: scale,
      child: const Stack(
        alignment: Alignment.center,
        children: [
          FittedBox(
            child: Icon(Icons.star_rounded, size: 400, color: AppColors.starYellow),
          ),
          FractionallySizedBox(heightFactor: 0.5, child: Pip()),
        ],
      ),
    );

    final words = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Great job!', style: baloo(s.isTablet ? 72 : 48, weight: 800)),
        ),
        SizedBox(height: s.gap),
        Container(
          height: s.smallTap,
          padding: const EdgeInsets.only(left: 10, right: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded,
                  size: s.smallTap * 0.75, color: AppColors.starYellow),
              const SizedBox(width: 6),
              Text('+1', style: baloo(s.smallTap * 0.5, weight: 800)),
            ],
          ),
        ),
        SizedBox(height: s.gap * 1.5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoundIconButton(
              icon: Icons.replay_rounded,
              semanticLabel: 'Play again',
              onPressed: () => context.go(widget.next),
            ),
            SizedBox(width: s.gap),
            Semantics(
              button: true,
              label: 'Next',
              child: Bouncy(
                onTap: () => context.go('/'),
                child: Container(
                  height: s.tap,
                  padding: EdgeInsets.only(left: s.tap * 0.45, right: s.tap * 0.35),
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Next',
                          style: baloo(s.tap * 0.4, weight: 800, color: Colors.white)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded,
                          size: s.tap * 0.45, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.sky100,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(s.pad),
          child: LayoutBuilder(
            builder: (context, c) => c.maxHeight > c.maxWidth
                ? Column(
                    children: [
                      Expanded(child: star),
                      SizedBox(height: s.gap),
                      words,
                      SizedBox(height: s.gap * 2),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: star),
                      SizedBox(width: s.gap * 1.5),
                      Expanded(child: Center(child: words)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
