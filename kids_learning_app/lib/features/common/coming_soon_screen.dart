import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../core/audio/audio_service.dart';
import '../../widgets/pip.dart';
import '../../widgets/round_icon_button.dart';

/// Pip with a message and a back button. Used for activities that are not
/// built yet, and when a pack is missing. [prompt] is said aloud, so the
/// child does not need to read the message.
class ComingSoonScreen extends StatefulWidget {
  const ComingSoonScreen({
    super.key,
    required this.message,
    required this.backTo,
    this.prompt,
  });

  final String message;
  final String backTo;
  final Prompt? prompt;

  @override
  State<ComingSoonScreen> createState() => _ComingSoonScreenState();
}

class _ComingSoonScreenState extends State<ComingSoonScreen> {
  @override
  void initState() {
    super.initState();
    final p = widget.prompt;
    // After the first frame, so the screen we came from has stopped its voice.
    if (p != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => AudioService.instance.say(p));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);
    final parts = <Widget>[
      Flexible(child: Pip(height: s.isShort ? 140 : 220)),
      SizedBox(width: s.gap, height: s.gap),
      Flexible(child: SpeechBubble(widget.message, fontSize: s.isTablet ? 28 : 22)),
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
                  onPressed: () => context.go(widget.backTo),
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
