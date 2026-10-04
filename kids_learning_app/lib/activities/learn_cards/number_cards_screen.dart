import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../packs/pack_manager.dart';
import '../../packs/pack_models.dart';
import '../../widgets/pack_image.dart';
import 'learn_cards_frame.dart';
import 'missing_pack_screen.dart';

/// Screen 5: swipe through 1 to 10 from the Numbers pack.
class NumberCardsScreen extends StatelessWidget {
  const NumberCardsScreen({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    final pack = PackManager.instance.packOfType('numbers');
    if (pack == null || pack.items.isEmpty) {
      return const MissingPackScreen(backTo: '/numbers');
    }
    return LearnCardsFrame(
      itemCount: pack.items.length,
      initialIndex: initialIndex,
      color: AppColors.numbersGreen,
      backTo: '/numbers',
      cardBuilder: (context, i) => _NumberCard(packId: pack.id, item: pack.items[i]),
    );
  }
}

class _NumberCard extends StatelessWidget {
  const _NumberCard({required this.packId, required this.item});

  final String packId;
  final PackItem item;

  @override
  Widget build(BuildContext context) {
    final value = item.number ?? int.tryParse(item.id) ?? 1;
    final number = FittedBox(
      child: Text(
        '$value',
        style: baloo(240, weight: 800, color: AppColors.numbersGreen, height: 1),
      ),
    );
    final objects = _CountedObjects(packId: packId, image: item.image, count: value);
    final label = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(item.label ?? item.word ?? '', style: baloo(40, weight: 800)),
    );

    return Semantics(
      label: item.label ?? '$value',
      child: CardSurface(
        child: LayoutBuilder(
          builder: (context, c) {
            if (cardIsTall(c)) {
              return Column(
                children: [
                  Expanded(flex: 3, child: number),
                  const SizedBox(height: 8),
                  Expanded(flex: 5, child: objects),
                  const SizedBox(height: 8),
                  label,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 2, child: number),
                const SizedBox(width: 24),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Expanded(child: objects),
                      const SizedBox(height: 8),
                      label,
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

/// Shows the object [count] times, each with its count underneath.
/// Up to 5 in one row; 6 to 10 split into two even rows (3+3 ... 5+5).
class _CountedObjects extends StatelessWidget {
  const _CountedObjects({
    required this.packId,
    required this.image,
    required this.count,
  });

  final String packId;
  final String? image;
  final int count;

  @override
  Widget build(BuildContext context) {
    final perRow = count <= 5 ? count : (count / 2).ceil();
    final rows = (count / perRow).ceil();
    return LayoutBuilder(
      builder: (context, box) {
        final cell = [box.maxWidth / perRow, box.maxHeight / rows, 160.0]
            .reduce((a, b) => a < b ? a : b);
        final imageSize = cell * 0.62;
        final badge = cell * 0.26;
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            children: [
              for (var n = 1; n <= count; n++)
                SizedBox(
                  width: cell,
                  height: cell,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: imageSize,
                        height: imageSize,
                        child: PackImage(packId: packId, path: image),
                      ),
                      Container(
                        width: badge,
                        height: badge,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.numbersGreen,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$n',
                          style: baloo(badge * 0.55,
                              weight: 800, color: Colors.white, height: 1),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
