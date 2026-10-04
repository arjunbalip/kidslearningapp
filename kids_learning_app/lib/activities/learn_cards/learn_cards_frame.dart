import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../widgets/round_icon_button.dart';
import '../../widgets/top_bar.dart';

/// Shared layout for swipeable learn cards (letters and numbers).
///
/// Portrait: card fills the screen; previous, replay and next sit in a row
/// underneath (easy to reach with thumbs).
/// Landscape: previous and next beside the card; replay in the top bar.
///
/// Going past the last card opens the Reward screen, which returns to [backTo].
class LearnCardsFrame extends StatefulWidget {
  const LearnCardsFrame({
    super.key,
    required this.itemCount,
    required this.initialIndex,
    required this.color,
    required this.backTo,
    required this.cardBuilder,
  });

  final int itemCount;
  final int initialIndex;
  final Color color;
  final String backTo;
  final Widget Function(BuildContext context, int index) cardBuilder;

  @override
  State<LearnCardsFrame> createState() => _LearnCardsFrameState();
}

class _LearnCardsFrameState extends State<LearnCardsFrame> {
  late final PageController _pages;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.itemCount - 1).toInt();
    _pages = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _previous() => _goTo(_current - 1);

  void _next() {
    if (_current < widget.itemCount - 1) {
      _goTo(_current + 1);
    } else {
      context.go('/reward', extra: widget.backTo);
    }
  }

  void _replay() {
    // Voice playback arrives with the audio milestone.
  }

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);

    final pager = PageView.builder(
      controller: _pages,
      itemCount: widget.itemCount,
      onPageChanged: (i) => setState(() => _current = i),
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: widget.cardBuilder(context, i),
      ),
    );

    final previous = RoundIconButton(
      icon: Icons.arrow_back_ios_new_rounded,
      semanticLabel: 'Previous',
      color: widget.color,
      onPressed: _current > 0 ? _previous : null,
    );
    final next = RoundIconButton(
      icon: Icons.arrow_forward_ios_rounded,
      semanticLabel: 'Next',
      color: AppColors.brandOrange,
      filled: true,
      onPressed: _next,
    );
    final replay = RoundIconButton(
      icon: Icons.volume_up_rounded,
      semanticLabel: 'Hear it again',
      color: widget.color,
      filled: true,
      onPressed: _replay,
    );
    final progress = Semantics(
      label: 'Card ${_current + 1} of ${widget.itemCount}',
      child: SizedBox(
        width: s.isTablet ? 200 : 120,
        height: 10,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (_current + 1) / widget.itemCount,
            color: widget.color,
            backgroundColor: AppColors.line,
          ),
        ),
      ),
    );
    final back = RoundIconButton(
      icon: Icons.arrow_back_rounded,
      semanticLabel: 'Back',
      color: widget.color,
      onPressed: () => context.go(widget.backTo),
    );

    // Decide the layout from the space this screen really has.
    Widget layout(bool portrait) {
      if (portrait) {
      return Column(
        children: [
          TopBar(leading: back, center: progress),
          SizedBox(height: s.gap),
          Expanded(child: pager),
          SizedBox(height: s.gap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [previous, replay, next],
          ),
        ],
      );
      }
      return Column(
        children: [
          TopBar(
            leading: back,
            center: Row(
              mainAxisSize: MainAxisSize.min,
              children: [progress, const SizedBox(width: 16), replay],
            ),
          ),
          SizedBox(height: s.gap),
          Expanded(
            child: Row(
              children: [
                previous,
                SizedBox(width: s.gap),
                Expanded(child: pager),
                SizedBox(width: s.gap),
                next,
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(s.pad),
          child: LayoutBuilder(
            builder: (context, c) => layout(c.maxHeight > c.maxWidth),
          ),
        ),
      ),
    );
  }
}

/// White rounded card that holds one learn card's content.
class CardSurface extends StatelessWidget {
  const CardSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);
    return Container(
      padding: EdgeInsets.all(s.pad + 4),
      decoration: BoxDecoration(
        color: AppColors.surface200,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: child,
    );
  }
}

/// True when a card is taller than wide enough to stack its parts.
bool cardIsTall(BoxConstraints c) => c.maxWidth < c.maxHeight * 1.15;
