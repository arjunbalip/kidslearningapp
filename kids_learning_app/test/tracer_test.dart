import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_learning_app/activities/tracing/trace_shape.dart';
import 'package:kids_learning_app/activities/tracing/tracer.dart';

/// Drags along every checkpoint of the current stroke, [wobble] units off.
TraceEvent traceStroke(Tracer t, {double wobble = 0}) {
  final pts = t.current!.points;
  var e = t.down(pts.first + Offset(wobble, 0), Tracer.touchTolerance);
  for (final p in pts.skip(1)) {
    if (e == TraceEvent.strokeDone || e == TraceEvent.shapeDone) break;
    e = t.move(p + Offset(wobble, 0), Tracer.touchTolerance);
  }
  t.up();
  return e;
}

void main() {
  const tol = Tracer.touchTolerance;

  test('tracing L along its line finishes the shape', () {
    final t = Tracer(TraceShape.fromSvgs(['M 10 0 L 10 100 L 60 100'], TraceKind.upper));
    expect(traceStroke(t), TraceEvent.shapeDone);
    expect(t.isDone, isTrue);
  });

  test('a slightly wobbly finger still counts', () {
    final t = Tracer(TraceShape.fromSvgs(['M 10 0 L 10 100'], TraceKind.upper));
    expect(traceStroke(t, wobble: 7), TraceEvent.shapeDone);
  });

  test('starting away from the start dot gives a hint, not progress', () {
    final t = Tracer(TraceShape.fromSvgs(['M 10 0 L 10 100'], TraceKind.upper));
    expect(t.down(const Offset(10, 90), tol), TraceEvent.hint);
    expect(t.reached, 0);
  });

  test('wandering off pauses, keeps progress, and can carry on', () {
    final t = Tracer(TraceShape.fromSvgs(['M 10 0 L 10 100'], TraceKind.upper));
    t.down(const Offset(10, 0), tol);
    t.move(const Offset(10, 40), tol);
    final kept = t.reached;
    expect(t.move(const Offset(60, 40), tol), TraceEvent.hint);
    expect(t.tracing, isFalse);
    expect(t.reached, kept);
    t.up();
    // Carry on from where the stroke stopped.
    expect(t.down(const Offset(10, 40), tol), isNot(TraceEvent.hint));
    expect(t.move(const Offset(10, 100), tol), TraceEvent.shapeDone);
  });

  test('a fast swipe does not skip a stroke it never followed', () {
    final t = Tracer(TraceShape.fromSvgs(['M 10 0 L 10 100 L 60 100'], TraceKind.upper));
    t.down(const Offset(10, 0), tol);
    // Straight across, cutting the corner: wanders off, does not finish.
    expect(t.move(const Offset(60, 100), tol), TraceEvent.hint);
    expect(t.isDone, isFalse);
  });

  test('strokes go in order, and the dot on i is one tap', () {
    final t = Tracer(TraceShape.fromSvgs(['M 30 50 L 30 100', 'M 30 26 L 30 27'], TraceKind.lower));
    expect(traceStroke(t), TraceEvent.strokeDone);
    expect(t.current!.isDot, isTrue);
    expect(t.down(const Offset(31, 27), tol), TraceEvent.shapeDone);
  });

  test('every shape in the content packs can be traced', () {
    for (final file in ['content/letters-en/pack.json', 'content/numbers-en/pack.json']) {
      final pack = jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
      for (final item in pack['items'] as List<dynamic>) {
        final trace = (item as Map<String, dynamic>)['trace'] as Map<String, dynamic>;
        for (final entry in trace.entries) {
          final kind = TraceKind.values.firstWhere((k) => k.key == entry.key);
          final svgs = [for (final s in entry.value as List<dynamic>) '$s'];
          final t = Tracer(TraceShape.fromSvgs(svgs, kind));
          var e = TraceEvent.none;
          while (!t.isDone) {
            e = traceStroke(t);
            expect(e, anyOf(TraceEvent.strokeDone, TraceEvent.shapeDone),
                reason: '${item['id']} ${entry.key} stroke ${t.stroke}');
          }
          expect(e, TraceEvent.shapeDone);
        }
      }
    }
  });
}
