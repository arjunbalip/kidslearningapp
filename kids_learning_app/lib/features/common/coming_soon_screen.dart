import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../widgets/pip.dart';
import '../../widgets/round_icon_button.dart';

/// Pip with a message and a back button. Used for activities that are not
/// built yet, and when a pack is missing.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.message,
    required this.backTo,
  });

  final String message;
  final String backTo;

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);
    final parts = <Widget>[
      Flexible(child: Pip(height: s.isShort ? 140 : 220)),
      SizedBox(width: s.gap, height: s.gap),
      Flexible(child: SpeechBubble(message, fontSize: s.isTablet ? 28 : 22)),
    ];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(s.pad),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: 'Back',
                  onPressed: () => context.go(backTo),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Center(
                    child: c.maxHeight > c.maxWidth
                        ? Column(mainAxisSize: MainAxisSize.min, children: parts)
                        : Row(mainAxisSize: MainAxisSize.min, children: parts),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
