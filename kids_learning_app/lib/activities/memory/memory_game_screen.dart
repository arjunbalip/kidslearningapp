import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/audio/audio_service.dart';
import '../../core/progress/progress.dart';
import '../../packs/pack_manager.dart';
import '../../packs/pack_models.dart';
import '../../widgets/pack_image.dart';
import '../../widgets/round_icon_button.dart';
import '../../widgets/top_bar.dart';
import '../learn_cards/missing_pack_screen.dart';
import 'memory_game.dart';

/// Screen 9: Memory. Cards lie face down; the child opens two at a time.
/// A pair stays open with a gold glow; two different cards wiggle in amber
/// and close again after a short look. Levels: 3, 4, then 6 pairs (saved).
/// The refresh button deals new random letters at the same level.
class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key, this.pack});

  /// For tests only; normally the installed Letters pack is used.
  final PackData? pack;

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  PackData? _pack;
  late MemoryGame _game;
  int _deal =
      0; // bumps on every new deal; cancels old timers, restarts card widgets
  final Map<int, int> _wiggles = {}; // card -> wiggle count, replays the wiggle

  static const _lookTime =
      Duration(milliseconds: 1500); // before two different cards close
  static const _backTo = '/letters';

  @override
  void initState() {
    super.initState();
    _pack = widget.pack ?? PackManager.instance.packOfType('letters');
    if (_pack != null) {
      _newDeal();
      // After the first frame, so the screen we came from has stopped its voice.
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => AudioService.instance.say(Prompt.findPairs));
    }
  }

  @override
  void dispose() {
    _deal++;
    AudioService.instance.stopVoice();
    super.dispose();
  }

  int get _level => Progress.instance.memoryLevel
      .clamp(0, MemoryGame.levelPairs.length - 1)
      .toInt();

  void _newDeal() {
    _deal++;
    _wiggles.clear();
    _game = MemoryGame(
        itemCount: _pack!.items.length, pairs: MemoryGame.levelPairs[_level]);
  }

  void _refresh() => setState(_newDeal);

  void _tap(int card) {
    final pack = _pack!;
    final result = _game.flip(card);
    if (result == FlipResult.ignored) return;
    final clip = pack.items[_game.cards[card]].audio['name'];
    setState(() {});

    switch (result) {
      case FlipResult.first:
        AudioService.instance.sayPack(pack.id, clip);
      case FlipResult.match:
        AudioService.instance.effect(Sfx.pop);
        AudioService.instance.sayPack(pack.id, clip);
        if (_game.done) _finish();
      case FlipResult.noMatch:
        AudioService.instance.sayPack(pack.id, clip);
        final deal = _deal;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || deal != _deal) return;
          setState(() {
            for (final c in _game.open) {
              _wiggles[c] = (_wiggles[c] ?? 0) + 1;
            }
          });
        });
        Future.delayed(_lookTime, () {
          if (!mounted || deal != _deal) return;
          setState(_game.closeOpen);
        });
      case FlipResult.ignored:
        break;
    }
  }

  void _finish() {
    final deal = _deal;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || deal != _deal) return;
      AudioService.instance.effect(Sfx.chime);
      AudioService.instance.praise();
    });
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted || deal != _deal) return;
      Progress.instance
        ..memoryWon(MemoryGame.levelPairs.length - 1)
        ..gameFinished();
      context.go('/reward', extra: _backTo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pack = _pack;
    if (pack == null) return const MissingPackScreen(backTo: _backTo);
    final s = Screen.of(context);

    final found = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _game.pairs; i++)
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _game.pairsFound ? AppColors.starYellow : Colors.white,
              border: Border.all(color: AppColors.line, width: 3),
            ),
          ),
        SizedBox(width: s.gap),
        RoundIconButton(
          icon: Icons.refresh_rounded,
          semanticLabel: 'New cards',
          color: AppColors.lettersBlue,
          onPressed: _refresh,
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(s.pad),
          child: Column(
            children: [
              TopBar(
                leading: RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: 'Back',
                  color: AppColors.lettersBlue,
                  onPressed: () => context.go(_backTo),
                ),
                center: Semantics(
                  label: '${_game.pairsFound} of ${_game.pairs} pairs found',
                  child: found,
                ),
              ),
              SizedBox(height: s.gap),
              Expanded(child: _grid(pack, s)),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks the number of columns that gives the biggest cards.
  Widget _grid(PackData pack, Screen s) {
    return LayoutBuilder(builder: (context, c) {
      const aspect = 0.8; // card width / height
      final n = _game.cards.length;
      final gap = s.gap;
      var best = 0.0;
      var cols = 1;
      for (var k = 1; k <= n; k++) {
        final rows = (n / k).ceil();
        final w = math.min((c.maxWidth - gap * (k - 1)) / k,
            (c.maxHeight - gap * (rows - 1)) / rows * aspect);
        if (w > best) {
          best = w;
          cols = k;
        }
      }
      final cardW = math.max(best, s.tap);
      final rows = (n / cols).ceil();
      return Center(
        child: SizedBox(
          width: cardW * cols + gap * (cols - 1),
          height: cardW / aspect * rows + gap * (rows - 1),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < n; i++)
                SizedBox(
                  width: cardW,
                  height: cardW / aspect,
                  child: _MemoryCard(
                    // A new deal starts every card fresh, face down.
                    key: ValueKey('$_deal-$i'),
                    packId: pack.id,
                    item: pack.items[_game.cards[i]],
                    faceUp: _game.isFaceUp(i),
                    matched: _game.matched.contains(i),
                    wiggle: _wiggles[i] ?? 0,
                    onTap: () => _tap(i),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// One card: flips in 3D, wiggles in amber when it was not a pair,
/// bounces with a gold border when it was.
class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    super.key,
    required this.packId,
    required this.item,
    required this.faceUp,
    required this.matched,
    required this.wiggle,
    required this.onTap,
  });

  final String packId;
  final PackItem item;
  final bool faceUp;
  final bool matched;
  final int wiggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final letter = item.upper ?? item.id;
    return Semantics(
      button: !faceUp,
      label: faceUp ? letter : 'Card',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          // Wiggle: replays whenever [wiggle] goes up.
          key: ValueKey(wiggle),
          tween: Tween(begin: wiggle == 0 ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 600),
          builder: (context, w, child) => Transform.rotate(
            angle: math.sin(w * math.pi * 6) * 0.08 * (1 - w),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child!,
                // Gentle amber glow while wiggling: "not a pair". Never red.
                if (w < 1)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.hintAmber.withValues(alpha: 1 - w),
                            width: 5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: matched ? 1 : 0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, m, child) =>
                Transform.scale(scale: 1 + 0.06 * m, child: child),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: faceUp ? 1 : 0),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              builder: (context, t, _) {
                final showFront = t >= 0.5;
                // Turn around the vertical axis; the front is drawn mirrored back.
                final angle = t * math.pi;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(angle),
                  child: showFront
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: _front(letter),
                        )
                      : _back(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _back() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lettersBlue,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final star = c.maxWidth * 0.22;
        return Stack(
          children: [
            for (final (fx, fy, k) in const [
              (0.5, 0.5, 1.6),
              (0.2, 0.18, 0.8),
              (0.8, 0.82, 0.8),
              (0.82, 0.2, 0.6),
              (0.18, 0.8, 0.6)
            ])
              Positioned(
                left: c.maxWidth * fx - star * k / 2,
                top: c.maxHeight * fy - star * k / 2,
                child: Icon(Icons.star_rounded,
                    size: star * k,
                    color: Colors.white.withValues(alpha: k > 1 ? 0.9 : 0.35)),
              ),
          ],
        );
      }),
    );
  }

  Widget _front(String letter) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface200,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: matched ? AppColors.starYellow : AppColors.line,
          width: matched ? 5 : 2,
        ),
        boxShadow: matched
            ? [
                BoxShadow(
                    color: AppColors.starYellow.withValues(alpha: 0.6),
                    blurRadius: 14)
              ]
            : null,
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: FittedBox(
              child: Text(letter,
                  style: baloo(120,
                      weight: 800, color: AppColors.lettersBlue, height: 1)),
            ),
          ),
          Expanded(flex: 3, child: PackImage(packId: packId, path: item.image)),
        ],
      ),
    );
  }
}
