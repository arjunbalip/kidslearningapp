import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/audio/audio_service.dart';
import '../../core/progress/stars.dart';
import '../../packs/pack_manager.dart';
import '../../widgets/ask_grown_up.dart';
import '../../widgets/metro.dart';
import '../../widgets/pip.dart';

/// Screen 1: Home, as a Metro tile grid.
///
/// Tiles: Pip's greeting, Letters, Numbers, Stars and Grown-ups.
/// New worlds later (Colours, Shapes, older ages) are simply more tiles.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openWorld(BuildContext context, String type) {
    if (PackManager.instance.packOfType(type) == null) {
      showAskGrownUp(context);
    } else {
      AudioService.instance.say(type == 'letters' ? Prompt.letters : Prompt.numbers);
      context.go('/$type');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);

    List<MetroTileSpec> tiles(int cols) {
      final wideGreeting = cols == 4; // phones: greeting across the top
      return [
        MetroTileSpec(
          w: wideGreeting ? 4 : 2,
          h: 2,
          child: _GreetingTile(wide: wideGreeting),
        ),
        MetroTileSpec(
          w: 2,
          h: 2,
          child: MetroTile(
            color: AppColors.lettersBlue,
            label: 'Letters',
            onTap: () => _openWorld(context, 'letters'),
            child: const _BigGlyph('Aa'),
          ),
        ),
        MetroTileSpec(
          w: 2,
          h: 2,
          child: MetroTile(
            color: AppColors.numbersGreen,
            label: 'Numbers',
            onTap: () => _openWorld(context, 'numbers'),
            child: const _BigGlyph('123'),
          ),
        ),
        MetroTileSpec(
          w: 2,
          h: 1,
          child: MetroTile(
            color: AppColors.starYellow,
            label: '',
            semanticLabel: 'Stars',
            child: ValueListenableBuilder<int>(
              valueListenable: Stars.count,
              builder: (context, n, _) => FittedBox(
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 64, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('$n', style: baloo(56, weight: 800, height: 1)),
                  ],
                ),
              ),
            ),
          ),
        ),
        MetroTileSpec(
          w: 2,
          h: 1,
          child: MetroTile(
            color: AppColors.inkMuted,
            label: '',
            semanticLabel: 'Grown-ups: settings and downloads',
            onTap: () => context.push('/parent/gate'),
            child: FittedBox(
              child: Row(
                children: [
                  const Icon(Icons.settings_rounded, size: 40, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Grown-ups',
                      style: baloo(28, weight: 700, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    // canPop: false = the Android back button does nothing on Home,
    // so a toddler cannot close the app by accident.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface100,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(s.pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Kids Learning',
                      style: baloo(s.isTablet ? 36 : 26, weight: 800)),
                ),
                SizedBox(height: s.gap * 0.75),
                Expanded(child: MetroGrid(tiles: tiles)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A big white glyph ("Aa", "123") that fills its tile.
class _BigGlyph extends StatelessWidget {
  const _BigGlyph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: Text(text, style: baloo(160, weight: 800, color: Colors.white, height: 1)),
    );
  }
}

/// White tile with Pip and the greeting. Wide on phones (Pip beside the
/// words), square on tablets (Pip under the words).
class _GreetingTile extends StatelessWidget {
  const _GreetingTile({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final words = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        "Let's learn\nand play!",
        textAlign: TextAlign.center,
        style: baloo(30, weight: 800, height: 1.1),
      ),
    );
    return MetroTile(
      color: Colors.white,
      label: '',
      semanticLabel: "Pip says: let's learn and play!",
      child: wide
          ? Row(
              children: [
                const Expanded(child: Pip()),
                const SizedBox(width: 8),
                Expanded(child: words),
              ],
            )
          : Column(
              children: [
                words,
                const SizedBox(height: 8),
                const Expanded(child: Pip()),
              ],
            ),
    );
  }
}
