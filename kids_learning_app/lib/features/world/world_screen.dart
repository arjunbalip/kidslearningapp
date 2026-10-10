import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/audio/audio_service.dart';
import '../../core/progress/progress.dart';
import '../../packs/pack_manager.dart';
import '../../packs/pack_models.dart';
import '../../widgets/metro.dart';
import '../../widgets/pack_image.dart';
import '../../widgets/pip.dart';
import '../../widgets/round_icon_button.dart';
import '../../widgets/top_bar.dart';

enum WorldKind { letters, numbers }

/// Screen 2: a world menu (Letters or Numbers) as Metro tiles:
/// Learn, Trace and (for letters) an A to Z progress strip.
class WorldScreen extends StatelessWidget {
  const WorldScreen({super.key, required this.kind});

  final WorldKind kind;

  bool get _isLetters => kind == WorldKind.letters;
  String get _type => _isLetters ? 'letters' : 'numbers';
  Color get _color =>
      _isLetters ? AppColors.lettersBlue : AppColors.numbersGreen;
  Color get _deepColor =>
      _isLetters ? const Color(0xFF1D4ED8) : const Color(0xFF15803D);
  Color get _textColor =>
      _isLetters ? AppColors.lettersBlue : AppColors.numbersGreenText;

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(s.pad),
          child: ListenableBuilder(
            listenable: PackManager.instance,
            builder: (context, _) {
              final pack = PackManager.instance.packOfType(_type);
              return Column(
                children: [
                  TopBar(
                    leading: RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: 'Back to home',
                      color: _color,
                      size: s.smallTap + 8,
                      onPressed: () => context.go('/'),
                    ),
                    center: Text(
                      _isLetters ? 'Letters' : 'Numbers',
                      style: baloo(s.titleSize, weight: 800, color: _textColor),
                    ),
                  ),
                  SizedBox(height: s.gap * 0.75),
                  Expanded(
                    child: pack == null
                        ? const _NotDownloaded()
                        : MetroGrid(
                            tiles: (cols) => _tiles(context, pack, cols)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<MetroTileSpec> _tiles(BuildContext context, PackData pack, int cols) {
    final sample = pack.items.isEmpty
        ? null
        : pack.items[_isLetters ? 0 : (pack.items.length > 1 ? 1 : 0)];
    return [
      MetroTileSpec(
        w: 2,
        h: 2,
        child: MetroTile(
          color: _color,
          label: 'Learn',
          onTap: () => context.go('/$_type/learn/0'),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  child: Text(
                    _isLetters ? 'Aa' : '123',
                    style:
                        baloo(120, weight: 800, color: Colors.white, height: 1),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: PackImage(packId: pack.id, path: sample?.image)),
            ],
          ),
        ),
      ),
      _traceTile(
        context,
        label: _isLetters ? 'Trace ABC' : 'Trace',
        sample: _isLetters ? 'A' : '1',
        route: '/$_type/trace/0',
      ),
      if (_isLetters)
        _traceTile(
          context,
          label: 'Trace abc',
          sample: 'a',
          route: '/letters/trace-small/0',
        ),
      MetroTileSpec(
        w: 2,
        h: 2,
        child: MetroTile(
          color: AppColors.playPink,
          label: 'Play',
          onTap: () => context.go('/$_type/play'),
          child: const FittedBox(
            child:
                Icon(Icons.celebration_rounded, size: 150, color: Colors.white),
          ),
        ),
      ),
      MetroTileSpec(
        w: 2,
        h: 2,
        child: MetroTile(
          color: AppColors.brandOrange,
          label: 'Memory',
          onTap: () => context.go('/$_type/memory'),
          child: const FittedBox(
            child: Icon(Icons.style_rounded, size: 150, color: Colors.white),
          ),
        ),
      ),
      MetroTileSpec(
        w: cols,
        h: 1,
        child: MetroTile(
          color: Colors.white,
          label: '',
          semanticLabel: _isLetters ? 'Letters A to Z' : 'Numbers 1 to 10',
          child:
              _ProgressChips(pack: pack, isLetters: _isLetters, color: _color),
        ),
      ),
    ];
  }

  /// A tile with an outlined sample letter, like a shape waiting to be traced.
  MetroTileSpec _traceTile(
    BuildContext context, {
    required String label,
    required String sample,
    required String route,
  }) {
    return MetroTileSpec(
      w: 2,
      h: 2,
      child: MetroTile(
        color: _deepColor,
        label: label,
        onTap: () => context.go(route),
        child: FittedBox(
          child: Text(
            sample,
            style: baloo(150, weight: 800, height: 1).copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 6
                ..color = Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// One chip per letter or number, filled in as the child traces them:
/// outline = not yet; world colour = traced (for letters: capital or
/// small); gold = all done (capital and small, or the number).
class _ProgressChips extends StatelessWidget {
  const _ProgressChips(
      {required this.pack, required this.isLetters, required this.color});

  final PackData pack;
  final bool isLetters;
  final Color color;

  /// 0 = not traced, 1 = partly, 2 = all.
  int _level(PackItem item) {
    final p = Progress.instance;
    if (!isLetters) return p.isTraced('number', item.id) ? 2 : 0;
    final done = [p.isTraced('upper', item.id), p.isTraced('lower', item.id)]
        .where((d) => d)
        .length;
    return done;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Progress.instance,
      builder: (context, _) => LayoutBuilder(builder: (context, c) {
        // Fit all chips in up to 2 rows (3 on very narrow tiles).
        final n = pack.items.length;
        final rows =
            c.maxWidth / n >= 24 ? 1 : (c.maxWidth / (n / 2) >= 22 ? 2 : 3);
        final perRow = (n / rows).ceil();
        final chip = ((c.maxWidth - 4.0 * (perRow - 1)) / perRow)
            .clamp(14.0, isLetters ? 36.0 : 48.0)
            .toDouble();
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: c.maxWidth,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final item in pack.items) _chip(item, chip),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _chip(PackItem item, double size) {
    final level = _level(item);
    final fill = switch (level) {
      0 => null,
      1 => color,
      _ => AppColors.starYellow,
    };
    final text = level == 1
        ? Colors.white
        : (level == 2 ? AppColors.ink : AppColors.inkMuted);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border:
            fill == null ? Border.all(color: AppColors.line, width: 1.5) : null,
      ),
      child: Text(
        isLetters ? (item.upper ?? item.id) : '${item.number ?? item.id}',
        style: baloo(size * 0.5, weight: 700, color: text, height: 1),
      ),
    );
  }
}

/// Shown if someone reaches a world whose pack is not installed.
class _NotDownloaded extends StatefulWidget {
  const _NotDownloaded();

  @override
  State<_NotDownloaded> createState() => _NotDownloadedState();
}

class _NotDownloadedState extends State<_NotDownloaded> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => AudioService.instance.say(Prompt.askGrownUp));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final portrait = c.maxHeight > c.maxWidth;
      final children = [
        Flexible(
            child: Pip(
                height: (c.maxHeight * 0.45).clamp(80.0, 220.0).toDouble())),
        const SizedBox(width: 16, height: 16),
        const Flexible(child: SpeechBubble('Ask a grown-up to download this!')),
      ];
      return Center(
        child: portrait
            ? Column(mainAxisSize: MainAxisSize.min, children: children)
            : Row(mainAxisSize: MainAxisSize.min, children: children),
      );
    });
  }
}
