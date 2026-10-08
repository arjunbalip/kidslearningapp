import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/audio/audio_service.dart';
import 'trace_shape.dart';
import 'tracer.dart';

/// The tracing area: draws the faint letter, start dot and arrow, follows
/// the finger, shows a gentle amber hint when needed, and plays a little
/// celebration when the shape is finished.
///
/// A pink dot shows how the stroke goes as soon as the shape appears, and
/// again after 4 seconds without touching; [TraceCanvasState.showMe] shows
/// it at once.
class TraceCanvas extends StatefulWidget {
  const TraceCanvas({
    super.key,
    required this.shape,
    required this.color,
    required this.onDone,
  });

  final TraceShape shape;
  final Color color;
  final VoidCallback onDone;

  @override
  State<TraceCanvas> createState() => TraceCanvasState();
}

class TraceCanvasState extends State<TraceCanvas> with TickerProviderStateMixin {
  late final Tracer _tracer = Tracer(widget.shape);
  late final AnimationController _ghost = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _cheer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _idle;
  DateTime _lastHintVoice = DateTime(2000);

  // Shape units to pixels, set on each layout.
  double _scale = 1;
  Offset _origin = Offset.zero;

  static const _idleDelay = Duration(seconds: 4);
  static const _hintVoiceGap = Duration(seconds: 6); // do not nag
  static const _afterCheer = Duration(milliseconds: 800); // let praise finish
  static const _minTolerancePx = 22.0;

  @override
  void initState() {
    super.initState();
    // Show the way at once, looping until the child touches the screen.
    showMe();
  }

  @override
  void dispose() {
    _idle?.cancel();
    _ghost.dispose();
    _pulse.dispose();
    _cheer.dispose();
    super.dispose();
  }

  /// Plays the "watch how" dot along the current stroke.
  void showMe() {
    if (_tracer.isDone) return;
    _ghost.repeat();
  }

  void _restartIdle() {
    _idle?.cancel();
    if (_tracer.isDone) return;
    _idle = Timer(_idleDelay, showMe);
  }

  Offset _toShape(Offset local) => (local - _origin) / _scale;

  double _tolerance(PointerDeviceKind kind) {
    final base = kind == PointerDeviceKind.mouse
        ? Tracer.mouseTolerance
        : Tracer.touchTolerance;
    return math.max(base, _minTolerancePx / _scale);
  }

  void _handle(TraceEvent e) {
    switch (e) {
      case TraceEvent.hint:
        _pulse.forward(from: 0);
        final now = DateTime.now();
        if (now.difference(_lastHintVoice) > _hintVoiceGap) {
          _lastHintVoice = now;
          AudioService.instance.say(Prompt.hint);
        }
      case TraceEvent.strokeDone:
        HapticFeedback.selectionClick();
        AudioService.instance.effect(Sfx.pop);
      case TraceEvent.shapeDone:
        HapticFeedback.mediumImpact();
        AudioService.instance.effect(Sfx.chime);
        AudioService.instance.praise();
        _idle?.cancel();
        _cheer.forward(from: 0).then((_) => Future.delayed(_afterCheer)).then((_) {
          if (mounted) widget.onDone();
        });
      case TraceEvent.none:
      case TraceEvent.started:
      case TraceEvent.progress:
        break;
    }
    setState(() {});
  }

  void _onDown(PointerDownEvent e) {
    if (_tracer.isDone) return;
    _ghost.reset();
    _idle?.cancel();
    _handle(_tracer.down(_toShape(e.localPosition), _tolerance(e.kind)));
  }

  void _onMove(PointerMoveEvent e) {
    if (_tracer.isDone) return;
    _handle(_tracer.move(_toShape(e.localPosition), _tolerance(e.kind)));
  }

  void _onUp(PointerEvent e) {
    _tracer.up();
    _restartIdle();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final view = widget.shape.view;
      _scale = math.min(c.maxWidth / view.width, c.maxHeight / view.height);
      _origin = Offset(
            (c.maxWidth - view.width * _scale) / 2,
            (c.maxHeight - view.height * _scale) / 2,
          ) -
          view.topLeft * _scale;

      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onUp,
        child: AnimatedBuilder(
          animation: Listenable.merge([_ghost, _pulse, _cheer]),
          builder: (context, _) {
            final cheer = Curves.elasticOut.transform(_cheer.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                Transform.scale(
                  scale: 1 + 0.08 * math.sin(cheer * math.pi),
                  child: CustomPaint(
                    painter: _TracePainter(
                      tracer: _tracer,
                      color: widget.color,
                      scale: _scale,
                      origin: _origin,
                      ghost: _ghost.isAnimating ? _ghost.value : null,
                      pulse: _pulse.isAnimating ? _pulse.value : null,
                    ),
                  ),
                ),
                if (_cheer.value > 0) _StarBurst(t: _cheer.value),
              ],
            );
          },
        ),
      );
    });
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.tracer,
    required this.color,
    required this.scale,
    required this.origin,
    required this.ghost,
    required this.pulse,
  });

  final Tracer tracer;
  final Color color;
  final double scale;
  final Offset origin;
  final double? ghost; // 0..1 along the current stroke, or null
  final double? pulse; // 0..1 of the amber hint, or null

  static const _guideWidth = 18.0;
  static const _inkWidth = 14.0;
  static const _dotRadius = 9.0;

  Paint _stroke(Color c, double width) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = tracer.shape;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);

    _paintLines(canvas, shape);

    // Solid (not see-through), so crossing strokes do not look darker.
    final faint = Color.alphaBlend(
        AppColors.line.withValues(alpha: 0.45), AppColors.surface200);
    final guide = _stroke(faint, _guideWidth);
    final ink = _stroke(color, _inkWidth);
    final dotFill = Paint()..color = faint;

    for (var i = 0; i < shape.strokes.length; i++) {
      final s = shape.strokes[i];
      final done = i < tracer.stroke;
      if (s.isDot) {
        canvas.drawCircle(s.start, _dotRadius,
            done ? (Paint()..color = color) : dotFill);
      } else {
        canvas.drawPath(s.path, done ? ink : guide);
      }
    }

    final current = tracer.current;
    if (current != null) {
      if (!current.isDot) {
        // Little dots along the stroke to follow.
        final hintDot = Paint()..color = AppColors.inkMuted.withValues(alpha: 0.35);
        for (var j = 0; j < current.points.length; j += 3) {
          canvas.drawCircle(current.points[j], 1.6, hintDot);
        }
        canvas.drawPath(current.partUpTo(tracer.reached), ink);
      }
      if (!tracer.tracing) _paintStart(canvas, current);
      if (ghost != null) _paintGhost(canvas, current, ghost!);
    }

    final f = tracer.finger;
    if (f != null && tracer.tracing) {
      canvas.drawCircle(f, 8, Paint()..color = AppColors.starYellow);
      canvas.drawCircle(f, 8, _stroke(Colors.white, 2.5));
    }
    canvas.restore();
  }

  void _paintLines(Canvas canvas, TraceShape shape) {
    final hair = 1.5 / scale;
    final solid = Paint()
      ..color = AppColors.line
      ..strokeWidth = hair;
    final left = shape.view.left;
    final right = shape.view.right;
    void line(double y) => canvas.drawLine(Offset(left, y), Offset(right, y), solid);
    void dashed(double y) {
      for (var x = left; x < right; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, right), y), solid);
      }
    }

    line(TraceLines.top);
    dashed(TraceLines.middle);
    line(TraceLines.base);
    if (shape.kind == TraceKind.lower) dashed(TraceLines.tail);
  }

  void _paintStart(Canvas canvas, TraceStroke s) {
    final at = tracer.anchor!;
    final p = pulse;
    if (p != null) {
      // Gentle amber ring: "start here". Never red.
      canvas.drawCircle(
        at,
        _dotRadius + 14 * p,
        Paint()..color = AppColors.hintAmber.withValues(alpha: 0.5 * (1 - p)),
      );
    }
    canvas.drawCircle(
      at,
      _dotRadius,
      Paint()..color = p != null ? AppColors.hintAmber : AppColors.numbersGreen,
    );
    canvas.drawCircle(at, _dotRadius * 0.4, Paint()..color = Colors.white);

    if (tracer.reached == 0 && !s.isDot) {
      // Arrow showing which way to go.
      final d = s.startDirection;
      final normal = Offset(-d.dy, d.dx);
      final tip = at + d * (_dotRadius + 13);
      final back = tip - d * 9;
      final arrow = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((back + normal * 6).dx, (back + normal * 6).dy)
        ..lineTo((back - normal * 6).dx, (back - normal * 6).dy)
        ..close();
      canvas.drawPath(arrow, Paint()..color = AppColors.brandOrange);
    }
  }

  void _paintGhost(Canvas canvas, TraceStroke s, double t) {
    final at = s.isDot
        ? s.start
        : s.path.computeMetrics().first.getTangentForOffset(t * s.length)!.position;
    final fade = t < 0.85 ? 1.0 : (1 - t) / 0.15;
    canvas.drawCircle(
      at,
      10,
      Paint()..color = AppColors.playPink.withValues(alpha: 0.8 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _TracePainter old) => true;
}

/// Stars flying out from the middle when a shape is finished.
class _StarBurst extends StatelessWidget {
  const _StarBurst({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, c) {
        final r = c.biggest.shortestSide * 0.45 * Curves.easeOut.transform(t);
        final size = c.biggest.shortestSide * 0.12;
        final fade = t < 0.7 ? 1.0 : (1 - t) / 0.3;
        return Stack(
          children: [
            for (var i = 0; i < 8; i++)
              Positioned(
                left: c.maxWidth / 2 + r * math.cos(i * math.pi / 4) - size / 2,
                top: c.maxHeight / 2 + r * math.sin(i * math.pi / 4) - size / 2,
                child: Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Icon(Icons.star_rounded,
                      size: size, color: AppColors.starYellow),
                ),
              ),
          ],
        );
      }),
    );
  }
}
