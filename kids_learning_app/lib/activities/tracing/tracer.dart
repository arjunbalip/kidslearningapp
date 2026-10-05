import 'dart:math' as math;
import 'dart:ui';

import 'trace_shape.dart';

/// What happened after a touch, so the screen can react.
enum TraceEvent {
  none,
  started, // finger put down in the right place
  progress, // moved further along the stroke
  hint, // started in the wrong place or wandered off: show where to go
  strokeDone,
  shapeDone,
}

/// Follows the child's finger along a [TraceShape], stroke by stroke.
///
/// Forgiving rules for ages 2 to 5:
/// - A stroke starts only near its start dot (or where the child stopped).
/// - The finger moves the stroke on when it comes within [tolerance] of
///   the next checkpoints; small gaps are skipped.
/// - Wandering more than twice [tolerance] away only pauses the stroke.
///   Progress is kept, and lifting the finger keeps it too.
/// - What is drawn is the clean stroke up to the furthest checkpoint, so
///   the letter always looks neat.
///
/// All positions are in shape units (capital height is 100).
class Tracer {
  Tracer(this.shape);

  final TraceShape shape;

  /// Fraction of the capital height the finger may be off the line:
  /// touch 9%, mouse 6% (Technical Design).
  static const touchTolerance = 9.0;
  static const mouseTolerance = 6.0;

  /// How far ahead a quick finger may jump, in checkpoints.
  static const _lookAhead = 3;

  int stroke = 0; // current stroke
  int reached = 0; // checkpoints passed in the current stroke
  bool tracing = false; // finger down and following the stroke
  Offset? finger;
  Offset? _last;

  bool get isDone => stroke >= shape.strokes.length;
  TraceStroke? get current => isDone ? null : shape.strokes[stroke];

  /// Where the child should put their finger next.
  Offset? get anchor {
    final s = current;
    if (s == null) return null;
    return s.points[math.max(reached - 1, 0)];
  }

  void reset() {
    stroke = 0;
    reached = 0;
    tracing = false;
    finger = null;
    _last = null;
  }

  TraceEvent down(Offset p, double tolerance) {
    final s = current;
    if (s == null) return TraceEvent.none;
    finger = p;
    if (s.isDot) {
      if ((p - s.start).distance <= tolerance * 1.8) return _finishStroke();
      return TraceEvent.hint;
    }
    if ((p - anchor!).distance > tolerance * 1.8) return TraceEvent.hint;
    tracing = true;
    _last = p;
    final e = _advance(p, tolerance);
    return e == TraceEvent.none ? TraceEvent.started : e;
  }

  TraceEvent move(Offset p, double tolerance) {
    finger = p;
    if (!tracing || current == null) return TraceEvent.none;
    // Check points between the last and this position, so a fast swipe
    // does not jump over checkpoints.
    final from = _last ?? p;
    final steps = math.max(1, ((p - from).distance / (tolerance / 2)).ceil());
    var result = TraceEvent.none;
    for (var i = 1; i <= steps; i++) {
      final q = Offset.lerp(from, p, i / steps)!;
      final e = _advance(q, tolerance);
      if (e == TraceEvent.strokeDone || e == TraceEvent.shapeDone) return e;
      if (e == TraceEvent.hint) {
        tracing = false;
        return e;
      }
      if (e == TraceEvent.progress) result = e;
    }
    _last = p;
    return result;
  }

  void up() {
    tracing = false;
    finger = null;
    _last = null;
  }

  TraceEvent _advance(Offset p, double tolerance) {
    final s = current!;
    final n = s.points.length;
    final before = reached;
    var moved = true;
    while (moved && reached < n) {
      moved = false;
      final last = math.min(reached + _lookAhead, n - 1);
      for (var j = last; j >= reached; j--) {
        if ((p - s.points[j]).distance <= tolerance) {
          reached = j + 1;
          moved = true;
          break;
        }
      }
    }
    if (reached >= n) return _finishStroke();
    if (reached > before) return TraceEvent.progress;

    // Still near the stroke around the current position?
    final lo = math.max(0, reached - 3);
    final hi = math.min(n - 1, reached + _lookAhead);
    var nearest = double.infinity;
    for (var j = lo; j <= hi; j++) {
      nearest = math.min(nearest, (p - s.points[j]).distance);
    }
    return nearest > tolerance * 2 ? TraceEvent.hint : TraceEvent.none;
  }

  TraceEvent _finishStroke() {
    stroke++;
    reached = 0;
    tracing = false;
    _last = null;
    return isDone ? TraceEvent.shapeDone : TraceEvent.strokeDone;
  }
}
