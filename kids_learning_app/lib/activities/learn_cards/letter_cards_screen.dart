import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/audio/audio_service.dart';
import '../../core/progress/progress.dart';
import '../../packs/pack_manager.dart';
import '../../packs/pack_models.dart';
import '../../widgets/pack_image.dart';
import 'learn_cards_frame.dart';
import 'missing_pack_screen.dart';

/// Screen 3: swipe through A to Z from the Letters pack.
class LetterCardsScreen extends StatelessWidget {
  const LetterCardsScreen({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    final pack = PackManager.instance.packOfType('letters');
    if (pack == null || pack.items.isEmpty) {
      return const MissingPackScreen(backTo: '/letters');
    }
    return LearnCardsFrame(
      itemCount: pack.items.length,
      initialIndex: initialIndex,
      color: AppColors.lettersBlue,
      backTo: '/letters',
      onShow: (i) {
        AudioService.instance.sayPack(pack.id, pack.items[i].audio['card']);
        Progress.instance.markSeen('letters', pack.items[i].id);
      },
      cardBuilder: (context, i) => _LetterCard(packId: pack.id, item: pack.items[i]),
    );
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({required this.packId, required this.item});

  final String packId;
  final PackItem item;

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.lettersBlue;
    final upper = item.upper ?? '';
    final lower = item.lower ?? '';
    final word = item.word ?? '';

    final letters = FittedBox(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(upper, style: baloo(200, weight: 800, color: blue, height: 1)),
          const SizedBox(width: 12),
          Text(lower, style: baloo(160, weight: 800, color: blue, height: 1)),
        ],
      ),
    );
    final picture = PackImage(packId: packId, path: item.image);
    final wordText = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(children: [
          if (word.isNotEmpty)
            TextSpan(
                text: word.substring(0, 1),
                style: baloo(48, weight: 800, color: blue)),
          if (word.length > 1)
            TextSpan(text: word.substring(1), style: baloo(48, weight: 800)),
        ]),
      ),
    );

    return Semantics(
      label: '$upper. $upper is for $word',
      child: CardSurface(
        child: LayoutBuilder(
          builder: (context, c) {
            if (cardIsTall(c)) {
              return Column(
                children: [
                  Expanded(flex: 5, child: letters),
                  const SizedBox(height: 8),
                  Expanded(flex: 4, child: picture),
                  const SizedBox(height: 8),
                  wordText,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: letters),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: picture),
                      const SizedBox(height: 8),
                      wordText,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
