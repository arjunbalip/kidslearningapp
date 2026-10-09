import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/progress/progress.dart';
import '../../packs/pack_manager.dart';
import '../../packs/pack_models.dart';

/// Parent area: what the child has done, and a way to start again.
/// Traced letters are what count; "seen" only says which learn cards were
/// looked at.
class ProgressSection extends StatelessWidget {
  const ProgressSection({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset progress?', style: baloo(22, weight: 700)),
        content: Text(
          'Stars, traced letters and numbers, and games are cleared. Downloaded packs are kept.',
          style: baloo(16, weight: 500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) await Progress.instance.reset();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Progress.instance, PackManager.instance]),
      builder: (context, _) {
        final p = Progress.instance;
        final letters = PackManager.instance.packOfType('letters');
        final numbers = PackManager.instance.packOfType('numbers');

        String of(int done, PackData? pack) =>
            pack == null ? '$done' : '$done of ${pack.items.length}';

        return Container(
          padding: const EdgeInsets.all(AppSpace.s4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.starYellow, size: 32),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Text('${p.stars} stars · ${p.gamesFinished} games finished',
                        style: baloo(18, weight: 700)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s2),
              _Row(
                label: 'Capitals traced',
                value: of(p.traced('upper').length, letters),
                pack: letters,
                done: p.traced('upper'),
              ),
              _Row(
                label: 'Small letters traced',
                value: of(p.traced('lower').length, letters),
                pack: letters,
                done: p.traced('lower'),
              ),
              _Row(
                label: 'Numbers traced',
                value: of(p.traced('number').length, numbers),
                pack: numbers,
                done: p.traced('number'),
              ),
              const SizedBox(height: AppSpace.s2),
              Text(
                'Seen in Learn: letters ${of(p.seen('letters').length, letters)}, '
                'numbers ${of(p.seen('numbers').length, numbers)}',
                style: baloo(15, weight: 500, color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpace.s2),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmReset(context),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset progress'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "Capitals traced 5 of 26" with the letters themselves, done ones bold.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.pack, required this.done});

  final String label;
  final String value;
  final PackData? pack;
  final Set<String> done;

  @override
  Widget build(BuildContext context) {
    final items = pack?.items ?? const <PackItem>[];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $value', style: baloo(16, weight: 600)),
          if (items.isNotEmpty)
            Wrap(
              spacing: 6,
              children: [
                for (final i in items)
                  Text(
                    label.startsWith('Small') ? (i.lower ?? i.id) : (i.upper ?? '${i.number ?? i.id}'),
                    style: baloo(16,
                        weight: done.contains(i.id) ? 800 : 500,
                        color: done.contains(i.id) ? AppColors.ink : AppColors.line),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
