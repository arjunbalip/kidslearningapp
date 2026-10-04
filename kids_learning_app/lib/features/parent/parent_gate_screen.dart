import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../widgets/round_icon_button.dart';
import 'parent_access.dart';

/// Screen 7: a simple sum that toddlers cannot solve but grown-ups can.
/// A wrong answer just shows a new question.
class ParentGateScreen extends StatefulWidget {
  const ParentGateScreen({super.key});

  @override
  State<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends State<ParentGateScreen> {
  final _random = Random();
  late int _a;
  late int _b;
  late List<int> _choices;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  void _newQuestion() {
    _a = 3 + _random.nextInt(7); // 3..9
    _b = 3 + _random.nextInt(7);
    final answer = _a + _b;
    final options = <int>{answer};
    while (options.length < 4) {
      final candidate = answer + _random.nextInt(9) - 4; // answer +/- 4
      if (candidate > 0) options.add(candidate);
    }
    _choices = options.toList()..shuffle(_random);
  }

  void _pick(int value) {
    if (value == _a + _b) {
      ParentAccess.open();
      context.pushReplacement('/parent/packs');
    } else {
      setState(_newQuestion);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface300,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(s.pad),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: RoundIconButton(
                  icon: Icons.close_rounded,
                  semanticLabel: 'Close and go back',
                  color: AppColors.inkMuted,
                  size: s.smallTap,
                  onPressed: _close,
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Container(
                        padding: EdgeInsets.all(s.isTablet ? 32 : 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!s.isShort) ...[
                              const Icon(Icons.lock_outline_rounded,
                                  size: 40, color: AppColors.ink),
                              const SizedBox(height: 4),
                            ],
                            Text('For grown-ups',
                                style: baloo(s.isTablet ? 32 : 26, weight: 700)),
                            Text(
                              'Answer to open settings and downloads.',
                              textAlign: TextAlign.center,
                              style: baloo(s.isTablet ? 20 : 16,
                                  weight: 500, color: AppColors.inkMuted),
                            ),
                            SizedBox(height: s.gap),
                            Text('$_a + $_b = ?',
                                style: baloo(s.isTablet ? 52 : 40, weight: 800)),
                            SizedBox(height: s.gap),
                            LayoutBuilder(builder: (context, c) {
                              // Narrow phone: 2 x 2 grid. Wider: one row of 4.
                              final perRow = c.maxWidth < 380 ? 2 : 4;
                              const spacing = 12.0;
                              final w = (c.maxWidth - spacing * (perRow - 1)) / perRow;
                              return Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                children: [
                                  for (final v in _choices)
                                    SizedBox(width: w, child: _answerButton(v)),
                                ],
                              );
                            }),
                          ],
                        ),
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

  Widget _answerButton(int value) {
    return SizedBox(
      height: 64,
      child: OutlinedButton(
        onPressed: () => _pick(value),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.inkMuted, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Text('$value', style: baloo(28, weight: 700)),
      ),
    );
  }
}
