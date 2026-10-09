import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/audio/audio_service.dart';
import '../../core/progress/progress.dart';
import '../../packs/pack_manager.dart';
import '../../packs/pack_models.dart';
import '../../widgets/round_icon_button.dart';
import '../../widgets/top_bar.dart';
import '../learn_cards/learn_cards_frame.dart';
import '../learn_cards/missing_pack_screen.dart';
import 'trace_canvas.dart';
import 'trace_shape.dart';

/// Screen 4: trace capitals, small letters or numbers, one at a time.
///
/// No swiping here (it would fight with tracing): previous, "show me" and
/// next are buttons. Each finished shape adds a star and moves on by
/// itself; after the last one comes the Reward screen.
/// Portrait: buttons under the card. Landscape: previous and next beside it.
class TraceScreen extends StatefulWidget {
  const TraceScreen({super.key, required this.kind, required this.initialIndex});

  final TraceKind kind;
  final int initialIndex;

  @override
  State<TraceScreen> createState() => _TraceScreenState();
}

class _TraceScreenState extends State<TraceScreen> {
  // A new key per shape starts each one fresh.
  var _canvas = GlobalKey<TraceCanvasState>();
  final Map<int, TraceShape> _shapes = {};
  late int _current = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    // After the first frame, so the screen we came from has stopped its voice.
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce(first: true));
  }

  @override
  void dispose() {
    AudioService.instance.stopVoice();
    super.dispose();
  }

  PackData? get _pack => PackManager.instance.packOfType(_isNumbers ? 'numbers' : 'letters');

  /// Says the shape's name; the first time, "Put your finger on the green dot" first.
  void _announce({bool first = false}) {
    final pack = _pack;
    if (pack == null || !mounted) return;
    final items = _items(pack);
    if (items.isEmpty) return;
    final name = items[_current.clamp(0, items.length - 1).toInt()].audio['name'];
    if (first) {
      AudioService.instance.sayThen(Prompt.traceStart, pack.id, name);
    } else {
      AudioService.instance.sayPack(pack.id, name);
    }
  }

  bool get _isNumbers => widget.kind == TraceKind.number;
  String get _backTo => _isNumbers ? '/numbers' : '/letters';
  Color get _color => _isNumbers ? AppColors.numbersGreen : AppColors.lettersBlue;

  List<PackItem> _items(PackData pack) => [
        for (final i in pack.items)
          if ((i.trace[widget.kind.key] ?? const []).isNotEmpty) i,
      ];

  TraceShape _shape(PackItem item, int index) => _shapes.putIfAbsent(
      index, () => TraceShape.fromSvgs(item.trace[widget.kind.key]!, widget.kind));

  void _goTo(int index, int count) {
    if (index >= count) {
      context.go('/reward', extra: _backTo);
      return;
    }
    setState(() {
      _current = index.clamp(0, count - 1).toInt();
      _canvas = GlobalKey<TraceCanvasState>();
    });
    _announce();
  }

  @override
  Widget build(BuildContext context) {
    final pack = _pack;
    if (pack == null) return MissingPackScreen(backTo: _backTo);
    final items = _items(pack);
    if (items.isEmpty) {
      return MissingPackScreen(backTo: _backTo, needsUpdate: true);
    }
    final count = items.length;
    final index = _current.clamp(0, count - 1).toInt();
    final s = Screen.of(context);

    final card = CardSurface(
      child: TraceCanvas(
        key: _canvas,
        shape: _shape(items[index], index),
        color: _color,
        onDone: () {
          Progress.instance
            ..addStar()
            ..markTraced(widget.kind.key, items[index].id);
          _goTo(index + 1, count);
        },
      ),
    );

    final previous = RoundIconButton(
      icon: Icons.arrow_back_ios_new_rounded,
      semanticLabel: 'Previous',
      color: _color,
      onPressed: index > 0 ? () => _goTo(index - 1, count) : null,
    );
    final next = RoundIconButton(
      icon: Icons.arrow_forward_ios_rounded,
      semanticLabel: 'Next',
      color: AppColors.brandOrange,
      filled: true,
      onPressed: () => _goTo(index + 1, count),
    );
    final showMe = RoundIconButton(
      icon: Icons.touch_app_rounded,
      semanticLabel: 'Show me how',
      color: _color,
      filled: true,
      onPressed: () => _canvas.currentState?.showMe(),
    );
    final progress = Semantics(
      label: '${index + 1} of $count',
      child: SizedBox(
        width: s.isTablet ? 200 : 120,
        height: 10,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (index + 1) / count,
            color: _color,
            backgroundColor: AppColors.line,
          ),
        ),
      ),
    );
    final back = RoundIconButton(
      icon: Icons.arrow_back_rounded,
      semanticLabel: 'Back',
      color: _color,
      onPressed: () => context.go(_backTo),
    );

    Widget layout(bool portrait) {
      if (portrait) {
        return Column(
          children: [
            TopBar(leading: back, center: progress),
            SizedBox(height: s.gap),
            Expanded(child: card),
            SizedBox(height: s.gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [previous, showMe, next],
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
              children: [progress, const SizedBox(width: 16), showMe],
            ),
          ),
          SizedBox(height: s.gap),
          Expanded(
            child: Row(
              children: [
                previous,
                SizedBox(width: s.gap),
                Expanded(child: card),
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
