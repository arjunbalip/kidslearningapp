import 'package:flutter/material.dart';

import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/audio/audio_service.dart';
import 'pip.dart';
import 'round_icon_button.dart';

/// Shown when a child taps a world whose pack is not downloaded yet.
Future<void> showAskGrownUp(BuildContext context) {
  AudioService.instance.say(Prompt.askGrownUp);
  return showDialog<void>(
    context: context,
    builder: (context) => const _AskGrownUpDialog(),
  );
}

class _AskGrownUpDialog extends StatelessWidget {
  const _AskGrownUpDialog();

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);
    return Dialog(
      backgroundColor: AppColors.surface100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.all(s.pad + 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pip(height: s.isShort ? 90 : 140),
              SizedBox(height: s.gap),
              const SpeechBubble('Ask a grown-up to download this!'),
              SizedBox(height: s.gap),
              Text(
                'Grown-ups: tap the gear on the home screen, then Download.',
                textAlign: TextAlign.center,
                style: baloo(16, weight: 600, color: AppColors.inkMuted),
              ),
              SizedBox(height: s.gap),
              RoundIconButton(
                icon: Icons.check_rounded,
                semanticLabel: 'OK',
                color: AppColors.brandOrange,
                filled: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
