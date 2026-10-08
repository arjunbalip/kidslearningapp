import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/audio/audio_service.dart';
import '../../packs/pack_manager.dart';
import '../../packs/pack_models.dart';
import '../../widgets/pip.dart';
import '../../widgets/round_icon_button.dart';
import '../../widgets/top_bar.dart';
import '../learn_cards/missing_pack_screen.dart';
import 'cannon_game.dart';

/// Screen 7: Balloon Cannon. Balloons with numbers or letters float in the
/// sky; Pip's cannon shows which one comes next, and the child taps the
/// balloons in order. Right: the ball pops it and its name is said.
/// Wrong: the ball bounces off, the balloon wiggles in amber, "Try again!".
/// 5 rounds, then the Reward screen.
///
/// Everything is drawn by one painter, driven by a ticker (like a game
/// loop); the rules live in [CannonGame].
class CannonGameScreen extends StatefulWidget {
  const CannonGameScreen({super.key, required this.numbers, this.pack});

  final bool numbers;

  /// For tests only; normally the installed pack is used.
  final PackData? pack;

  @override
  State<CannonGameScreen> createState() => _CannonGameScreenState();
}

class _Balloon {
  _Balloon(this.itemIndex, this.label, this.color, this.phase, this.spawnAt);

  final int itemIndex;
  final String label;
  final Color color;
  final double phase; // so balloons do not bob together
  final double spawnAt;
  Offset base = Offset.zero; // centre in pixels, set by layout
  double? popAt;
  double? wiggleAt;
}

class _Shot {
  _Shot(this.from, this.control, this.to, this.balloon, this.start, this.hit);

  final Offset from, control, to;
  final _Balloon balloon;
  final double start;
  final bool hit;
}

/// Sizes and places that follow the screen.
class _Geometry {
  _Geometry(this.size, Screen s) {
    final shortest = math.min(size.width, size.height);
    groundTop = size.height * 0.84;
    pipHeight = (shortest * 0.24).clamp(80.0, 170.0).toDouble();
    cannonLength = (shortest * 0.17).clamp(56.0, 130.0).toDouble();
    pivot = Offset(s.pad + pipHeight * 0.85 + cannonLength * 0.35,
        groundTop - cannonLength * 0.12);
    radius = (shortest * 0.085).clamp(s.tap * 0.6, 78.0).toDouble();
    final top = s.pad + s.tap + 12 + radius * 1.2; // below the top bar
    play = Rect.fromLTRB(radius * 1.3, top, size.width - radius * 1.3,
        math.max(top + radius, groundTop - radius * 1.9));
    cannonZone = Rect.fromLTRB(0, pivot.dy - cannonLength * 1.7,
        pivot.dx + cannonLength * 1.4, size.height);
  }

  final Size size;
  late final double groundTop, pipHeight, cannonLength, radius;
  late final Offset pivot;
  late final Rect play, cannonZone;
}

class _CannonGameScreenState extends State<CannonGameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  final _random = math.Random();
  double _now = 0; // seconds since the screen opened

  PackData? _pack;
  List<PackItem> _items = const [];
  CannonGame? _game;
  List<_Balloon> _balloons = [];
  _Shot? _shot;
  double _aim = -0.7; // cannon angle, radians (0 = right, negative = up)
  _Geometry? _geo;
  Size? _placedFor;
  int _roundToken = 0;
  Timer? _idle;

  static const _flight = 0.45; // seconds the ball flies
  static const _idleDelay = Duration(seconds: 7);
  static const _colors = [
    AppColors.lettersBlue,
    AppColors.numbersGreen,
    AppColors.brandOrange,
    AppColors.playPink,
    AppColors.starYellow,
  ];

  String get _backTo => widget.numbers ? '/numbers' : '/letters';

  @override
  void initState() {
    super.initState();
    _pack = widget.pack ??
        PackManager.instance.packOfType(widget.numbers ? 'numbers' : 'letters');
    _items = _pack?.items ?? const [];
    if (_items.length >= 2) {
      _game = CannonGame(itemCount: _items.length, random: _random);
      _makeBalloons();
      // After the first frame, so the screen we came from has stopped its voice.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _announceRound(first: true));
    }
    _ticker = createTicker((elapsed) {
      _now = elapsed.inMicroseconds / 1e6;
      _frame.value++;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _idle?.cancel();
    _frame.dispose();
    AudioService.instance.stopVoice();
    super.dispose();
  }

  String _label(PackItem i) =>
      widget.numbers ? '${i.number ?? i.id}' : (i.upper ?? i.id);

  void _makeBalloons() {
    final g = _game!;
    final shuffled = [...g.order]..shuffle(_random);
    final colors = [..._colors]..shuffle(_random); // a different colour each
    _balloons = [
      for (var k = 0; k < shuffled.length; k++)
        _Balloon(
            shuffled[k],
            _label(_items[shuffled[k]]),
            colors[k % colors.length],
            _random.nextDouble() * math.pi * 2,
            _now + k * 0.12),
    ];
    _placedFor = null; // place on the next layout
  }

  /// Puts balloons on a loose grid in the sky, away from the cannon.
  void _place(_Geometry geo) {
    final r = geo.radius;
    for (final gap in [2.7, 2.3, 2.0, 1.6]) {
      final step = r * gap;
      final cols = math.max(1, (geo.play.width / step).floor() + 1);
      final rows = math.max(1, (geo.play.height / step).floor() + 1);
      final slots = <Offset>[];
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < cols; x++) {
          final p = Offset(
            geo.play.left +
                (cols == 1
                    ? geo.play.width / 2
                    : geo.play.width * x / (cols - 1)),
            geo.play.top +
                (rows == 1
                    ? geo.play.height / 2
                    : geo.play.height * y / (rows - 1)),
          );
          if (!geo.cannonZone.inflate(r).contains(p)) slots.add(p);
        }
      }
      if (slots.length >= _balloons.length || gap == 1.6) {
        slots.shuffle(math.Random(_roundToken * 31 + _game!.round));
        for (var i = 0; i < _balloons.length; i++) {
          final jitter = Offset((_random.nextDouble() - 0.5) * r * 0.5,
              (_random.nextDouble() - 0.5) * r * 0.5);
          _balloons[i].base = slots[i % slots.length] + jitter;
        }
        return;
      }
    }
  }

  Offset _balloonAt(_Balloon b, double r) =>
      b.base + Offset(0, math.sin(_now * 1.6 + b.phase) * r * 0.12);

  Offset _muzzle(_Geometry g, double angle) =>
      g.pivot + Offset(math.cos(angle), math.sin(angle)) * g.cannonLength;

  // ------------------------------------------------------------- talking

  String? _nameClip(int itemIndex) => _items[itemIndex].audio['name'];

  void _announceRound({bool first = false}) {
    final g = _game, pack = _pack;
    if (g == null || pack == null || !mounted) return;
    if (first) {
      AudioService.instance
          .sayThen(Prompt.shootInOrder, pack.id, _nameClip(g.target!));
    } else {
      AudioService.instance.sayPack(pack.id, _nameClip(g.target!));
    }
    _restartIdle();
  }

  void _restartIdle() {
    _idle?.cancel();
    _idle = Timer(_idleDelay, () {
      final g = _game, pack = _pack;
      if (!mounted || g == null || pack == null || g.target == null) return;
      AudioService.instance.sayPack(pack.id, _nameClip(g.target!));
      _restartIdle();
    });
  }

  // ------------------------------------------------------------- playing

  void _onTap(TapDownDetails d) {
    final g = _game, geo = _geo;
    if (g == null || geo == null || _shot != null || g.roundDone) return;
    final r = geo.radius;
    _Balloon? hit;
    var best = double.infinity;
    for (final b in _balloons) {
      if (b.popAt != null || _now < b.spawnAt) continue;
      final dist = (_balloonAt(b, r) - d.localPosition).distance;
      if (dist < r * 1.25 && dist < best) {
        best = dist;
        hit = b;
      }
    }
    if (hit == null) return;
    _restartIdle();

    final to = _balloonAt(hit, r);
    // Aim so the ball leaves along the barrel, then arcs down onto the balloon.
    final control = Offset((geo.pivot.dx + to.dx) / 2,
        math.min(geo.pivot.dy, to.dy) - (to - geo.pivot).distance * 0.35);
    _aim = math.atan2(control.dy - geo.pivot.dy, control.dx - geo.pivot.dx);
    final from = _muzzle(geo, _aim);
    final right = g.target == hit.itemIndex;
    _shot = _Shot(from, control, to, hit, _now, right);
    AudioService.instance.effect(Sfx.boom);

    final token = _roundToken;
    Future.delayed(Duration(milliseconds: (_flight * 1000).round()), () {
      if (!mounted || token != _roundToken) return;
      _land(hit!, right);
    });
  }

  void _land(_Balloon b, bool right) {
    final g = _game!, pack = _pack!;
    if (right) {
      _shot = null;
      setState(() => g.shoot(b.itemIndex)); // round dots follow
      b.popAt = _now;
      AudioService.instance.effect(Sfx.pop);
      AudioService.instance.sayPack(pack.id, _nameClip(b.itemIndex));
      if (g.roundDone) _finishRound();
    } else {
      b.wiggleAt = _now;
      AudioService.instance
          .sayThen(Prompt.tryAgain, pack.id, _nameClip(g.target!));
      // Let the ball fall away before the next shot.
      final token = _roundToken;
      Future.delayed(const Duration(milliseconds: 550), () {
        if (mounted && token == _roundToken) _shot = null;
      });
    }
  }

  void _finishRound() {
    _idle?.cancel();
    final token = ++_roundToken;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || token != _roundToken) return;
      AudioService.instance.effect(Sfx.chime);
      AudioService.instance.praise();
    });
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (!mounted || token != _roundToken) return;
      final g = _game!;
      if (g.gameDone) {
        context.go('/reward', extra: _backTo);
        return;
      }
      setState(() {
        g.nextRound();
        _makeBalloons();
      });
      _announceRound();
    });
  }

  // ------------------------------------------------------------- building

  @override
  Widget build(BuildContext context) {
    if (_pack == null) return MissingPackScreen(backTo: _backTo);
    final s = Screen.of(context);
    final g = _game!;
    final color =
        widget.numbers ? AppColors.numbersGreen : AppColors.lettersBlue;

    final rounds = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < CannonGame.roundSizes.length; i++)
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < g.round || (i == g.round && g.roundDone)
                  ? AppColors.starYellow
                  : Colors.white,
              border: Border.all(
                  color: i == g.round ? AppColors.brandOrange : AppColors.line,
                  width: 3),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.sky100,
      body: LayoutBuilder(builder: (context, c) {
        final geo = _Geometry(Size(c.maxWidth, c.maxHeight), s);
        _geo = geo;
        if (_placedFor != geo.size) {
          _place(geo);
          _placedFor = geo.size;
        }
        return Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                label: 'Balloon game. Tap the balloons in order.',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _onTap,
                  child: CustomPaint(painter: _ScenePainter(this, geo, _frame)),
                ),
              ),
            ),
            Positioned(
              left: s.pad,
              top: geo.groundTop - geo.pipHeight * 0.92,
              child: IgnorePointer(child: Pip(height: geo.pipHeight)),
            ),
            // Pinned to the top: inside a plain Stack the bar would fill the
            // height and sit in the middle.
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.all(s.pad),
                  child: TopBar(
                    leading: RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: 'Back',
                      color: color,
                      onPressed: () => context.go(_backTo),
                    ),
                    center: Semantics(
                      label:
                          'Round ${g.round + 1} of ${CannonGame.roundSizes.length}',
                      child: rounds,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.st, this.geo, Listenable repaint)
      : super(repaint: repaint);

  final _CannonGameScreenState st;
  final _Geometry geo;
  final Map<String, TextPainter> _labels = {};

  double get now => st._now;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    final r = geo.radius;
    for (final b in st._balloons) {
      _paintBalloon(canvas, b, r);
    }
    _paintShot(canvas);
    _paintCannon(canvas);
  }

  void _paintSky(Canvas canvas, Size size) {
    final cloud = Paint()..color = Colors.white;
    final unit = math.min(size.width, size.height) * 0.06;
    for (final (fx, fy, k) in const [
      (0.12, 0.2, 1.0),
      (0.5, 0.13, 1.3),
      (0.86, 0.28, 1.1),
      (0.68, 0.55, 0.8)
    ]) {
      final c = Offset(size.width * fx, size.height * fy);
      final u = unit * k;
      canvas.drawOval(
          Rect.fromCenter(center: c, width: u * 3.2, height: u * 1.3), cloud);
      canvas.drawCircle(c + Offset(-u * 0.5, -u * 0.45), u * 0.7, cloud);
      canvas.drawCircle(c + Offset(u * 0.45, -u * 0.35), u * 0.55, cloud);
    }
    // Grass and the little hill under the cannon.
    final grass = Paint()..color = AppColors.numbersGreen;
    canvas.drawRect(
        Rect.fromLTRB(0, geo.groundTop, size.width, size.height), grass);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(geo.pivot.dx - geo.cannonLength * 0.3,
              geo.groundTop + geo.cannonLength * 0.15),
          width: geo.pivot.dx * 2.6,
          height: geo.cannonLength * 0.9),
      grass,
    );
  }

  void _paintBalloon(Canvas canvas, _Balloon b, double r) {
    final age = now - b.spawnAt;
    if (age < 0) return;
    final c = st._balloonAt(b, r);

    final pop = b.popAt;
    if (pop != null) {
      _paintPop(canvas, c, r, now - pop, b.color);
      return;
    }

    // Grow in when a round starts.
    final grow = Curves.elasticOut.transform((age / 0.6).clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(grow);

    // A wrong shot: wiggle and an amber glow (never red).
    final w = b.wiggleAt;
    final wiggleT = w == null ? 1.0 : (now - w);
    if (wiggleT < 0.6) {
      canvas.rotate(math.sin(wiggleT * 40) * 0.15 * (1 - wiggleT / 0.6));
      canvas.drawCircle(
        Offset(0, -r * 0.1),
        r * 1.25,
        Paint()
          ..color =
              AppColors.hintAmber.withValues(alpha: 0.55 * (1 - wiggleT / 0.6))
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.18,
      );
    }

    // Envelope with soft stripes.
    final env = Path()
      ..moveTo(0, r * 0.95)
      ..cubicTo(-r * 1.25, r * 0.25, -r * 1.05, -r * 1.15, 0, -r * 1.15)
      ..cubicTo(r * 1.05, -r * 1.15, r * 1.25, r * 0.25, 0, r * 0.95)
      ..close();
    canvas.drawPath(env, Paint()..color = b.color);
    canvas.save();
    canvas.clipPath(env);
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.28);
    for (final x in [-0.62, 0.62]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(r * x, 0), width: r * 0.42, height: r * 2.6),
          stripe);
    }
    canvas.restore();

    // Ropes and basket.
    final rope = Paint()
      ..color = AppColors.inkMuted
      ..strokeWidth = math.max(1.5, r * 0.04);
    canvas.drawLine(
        Offset(-r * 0.25, r * 0.85), Offset(-r * 0.2, r * 1.3), rope);
    canvas.drawLine(Offset(r * 0.25, r * 0.85), Offset(r * 0.2, r * 1.3), rope);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(-r * 0.28, r * 1.28, r * 0.28, r * 1.58),
          Radius.circular(r * 0.08)),
      Paint()..color = AppColors.inkMuted,
    );

    // The number or letter on a white disc.
    canvas.drawCircle(
        Offset(0, -r * 0.12), r * 0.58, Paint()..color = Colors.white);
    final textColor = b.color == AppColors.starYellow ? AppColors.ink : b.color;
    final tp = _labels.putIfAbsent(
      '${b.label}-${textColor.toARGB32()}',
      () => TextPainter(
        text: TextSpan(
            text: b.label,
            style: baloo(r * (b.label.length > 1 ? 0.62 : 0.8),
                weight: 800, color: textColor, height: 1)),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    tp.paint(canvas, Offset(-tp.width / 2, -r * 0.12 - tp.height / 2));
    canvas.restore();
  }

  void _paintPop(Canvas canvas, Offset c, double r, double t, Color color) {
    if (t > 0.7) return;
    // A quick flash of the balloon, then stars flying out.
    if (t < 0.12) {
      canvas.drawCircle(c, r * (1 + t * 3),
          Paint()..color = color.withValues(alpha: 1 - t / 0.12));
    }
    final fade = (1 - t / 0.7).clamp(0.0, 1.0);
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi * 2 / 10 + 0.3;
      final d = r * (0.4 + 2.2 * Curves.easeOut.transform(t / 0.7));
      final p = c + Offset(math.cos(a), math.sin(a)) * d;
      final paint = Paint()
        ..color =
            (i.isEven ? AppColors.starYellow : color).withValues(alpha: fade);
      _star(canvas, p, r * 0.18 * (1 - t / 1.4), paint);
    }
  }

  void _star(Canvas canvas, Offset c, double size, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? size : size * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  void _paintShot(Canvas canvas) {
    final shot = st._shot;
    if (shot == null) return;
    final t = (now - shot.start) / _CannonGameScreenState._flight;
    final ballR = geo.radius * 0.28;
    final ball = Paint()..color = AppColors.playPink;
    if (t <= 1) {
      final u = t.clamp(0.0, 1.0);
      final p = shot.from * ((1 - u) * (1 - u)) +
          shot.control * (2 * (1 - u) * u) +
          shot.to * (u * u);
      canvas.drawCircle(p, ballR, ball);
      canvas.drawCircle(p + Offset(-ballR * 0.3, -ballR * 0.3), ballR * 0.3,
          Paint()..color = Colors.white.withValues(alpha: 0.6));
    } else if (!shot.hit) {
      // Bounced off: drops away under gravity.
      final f = now - shot.start - _CannonGameScreenState._flight;
      final p = shot.to +
          Offset(-f * geo.radius * 2.5, f * f * geo.size.height * 2.2);
      canvas.drawCircle(p, ballR, ball);
    }
  }

  void _paintCannon(Canvas canvas) {
    final p = geo.pivot;
    final len = geo.cannonLength;
    final shot = st._shot;
    // Small recoil just after firing.
    final kick = shot == null
        ? 0.0
        : math.max(0.0, 1 - (now - shot.start) / 0.15) * len * 0.08;

    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(st._aim);
    canvas.translate(-kick, 0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(-len * 0.2, -len * 0.22, len, len * 0.22),
          Radius.circular(len * 0.2)),
      Paint()..color = AppColors.brandOrange,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(len * 0.84, -len * 0.27, len * 1.02, len * 0.27),
          Radius.circular(len * 0.08)),
      Paint()..color = AppColors.starYellow,
    );
    canvas.restore();

    // Wheel.
    canvas.drawCircle(
        p + Offset(0, len * 0.08), len * 0.26, Paint()..color = AppColors.ink);
    canvas.drawCircle(p + Offset(0, len * 0.08), len * 0.1,
        Paint()..color = AppColors.inkMuted);

    // Badge showing what to shoot next.
    final g = st._game;
    final target = g?.target;
    if (target != null) {
      final label = st._label(st._items[target]);
      final at = p + Offset(math.cos(st._aim), math.sin(st._aim)) * len * 0.42;
      final br = len * 0.27;
      canvas.drawCircle(at, br, Paint()..color = Colors.white);
      canvas.drawCircle(
          at,
          br,
          Paint()
            ..color = AppColors.playPink
            ..style = PaintingStyle.stroke
            ..strokeWidth = br * 0.16);
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: baloo(br * (label.length > 1 ? 0.95 : 1.25),
                weight: 800, color: AppColors.playPink, height: 1)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => true;
}
