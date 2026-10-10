import 'package:flutter/material.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/progress/progress.dart';
import '../../widgets/bouncy.dart';
import 'memory_game.dart';

/// Memory settings: big picture buttons, so no reading is needed.
/// - Letters (letters world only): ABC = capital pairs, abc = small pairs,
///   Aa = one capital with one small (the picture is hidden).
/// - Cards: 6, 8, 12 or 16.
/// - Auto: the level ladder that gets harder with each win.
/// Picking a type or a size switches Auto off. Every tap is saved at once.
class MemorySettingsDialog extends StatefulWidget {
  const MemorySettingsDialog({
    super.key,
    required this.type,
    required this.numbers,
    required this.color,
  });

  final String type; // "letters" or "numbers"
  final bool numbers;
  final Color color;

  @override
  State<MemorySettingsDialog> createState() => _MemorySettingsDialogState();
}

class _MemorySettingsDialogState extends State<MemorySettingsDialog> {
  late MemoryChoice _choice = Progress.instance.memoryChoice(widget.type);

  void _set(MemoryChoice c) {
    setState(() => _choice = c);
    Progress.instance.setMemoryChoice(widget.type, c);
  }

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);
    final manual = !_choice.auto;

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpace.s4, bottom: AppSpace.s2),
          child: Text(text,
              style: baloo(18, weight: 700, color: AppColors.inkMuted)),
        );

    return Dialog(
      backgroundColor: AppColors.surface100,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(s.pad + 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Memory', style: baloo(s.isTablet ? 32 : 26, weight: 800)),
              if (!widget.numbers) ...[
                heading('Letters'),
                Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  children: [
                    for (final (faces, label) in const [
                      ('capital', 'ABC'),
                      ('small', 'abc'),
                      ('mixed', 'Aa'),
                    ])
                      _Choice(
                        selected: manual && _choice.faces == faces,
                        color: widget.color,
                        label: _faceName(faces),
                        onTap: () =>
                            _set(_choice.copyWith(auto: false, faces: faces)),
                        builder: (fg) => Text(label,
                            style: baloo(s.labelSize,
                                weight: 800, color: fg, height: 1)),
                      ),
                  ],
                ),
              ],
              heading('Cards'),
              Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s2,
                children: [
                  for (final pairs in MemoryLevel.pairChoices)
                    _Choice(
                      selected: manual && _choice.pairs == pairs,
                      color: widget.color,
                      label: '${pairs * 2} cards',
                      onTap: () =>
                          _set(_choice.copyWith(auto: false, pairs: pairs)),
                      builder: (fg) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.style_rounded, size: 26, color: fg),
                          const SizedBox(width: 6),
                          Text('${pairs * 2}',
                              style: baloo(s.labelSize,
                                  weight: 800, color: fg, height: 1)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.s4),
              _Choice(
                selected: _choice.auto,
                color: AppColors.starYellow,
                label: 'Auto, gets harder as you win',
                onTap: () => _set(_choice.copyWith(auto: true)),
                builder: (fg) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 28, color: fg),
                    const SizedBox(width: 8),
                    Text('Auto',
                        style: baloo(s.labelSize * 0.85,
                            weight: 800, color: fg, height: 1)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s6),
              Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  button: true,
                  label: 'Play',
                  child: Bouncy(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: s.tap,
                      padding: EdgeInsets.symmetric(horizontal: s.tap * 0.4),
                      decoration: BoxDecoration(
                        color: AppColors.brandOrange,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: s.tap * 0.5),
                          const SizedBox(width: 6),
                          Text('Play',
                              style: baloo(s.tap * 0.38,
                                  weight: 800, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _faceName(String faces) => switch (faces) {
        'small' => 'Small letters',
        'mixed' => 'Capital and small',
        _ => 'Capital letters',
      };
}

/// A big choice button: filled in [color] when selected, white otherwise.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.color,
    required this.label,
    required this.onTap,
    required this.builder,
  });

  final bool selected;
  final Color color;
  final String label;
  final VoidCallback onTap;

  /// Builds the content in the given text and icon colour.
  final Widget Function(Color fg) builder;

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);
    final onColor =
        color == AppColors.starYellow ? AppColors.ink : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Bouncy(
        onTap: onTap,
        // Only as wide as its content (a centred container would fill the row).
        child: IntrinsicWidth(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints:
                BoxConstraints(minWidth: s.tap * 1.3, minHeight: s.tap),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: selected ? color : AppColors.line, width: 3),
            ),
            child: builder(selected ? onColor : AppColors.ink),
          ),
        ),
      ),
    );
  }
}
