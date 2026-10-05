import 'dart:math' as math;
import 'dart:ui';

import 'package:path_parsing/path_parsing.dart';

/// Which set of shapes a tracing screen shows.
enum TraceKind {
  upper('upper'),
  lower('lower'),
  number('number');

  const TraceKind(this.key);

  /// Key in an item's "trace" map in pack.json.
  final String key;
}

/// Writing-paper lines in shape units: capitals and numbers sit between
/// [top] and [base]; small letters use [middle] and dip to [tail].
class TraceLines {
  TraceLines._();

  static const top = 0.0;
  static const middle = 50.0;
  static const base = 100.0;
  static const tail = 150.0;
}

/// One stroke: its path plus checkpoints spaced evenly along it.
class TraceStroke {
  TraceStroke._(this.path, this.points, this.distances, this.length);

  /// Gap between checkpoints, in shape units (capital height is 100).
  static const spacing = 4.0;

  /// Strokes shorter than this are dots (the dot on i and j): one tap.
  static const dotLength = 6.0;

  factory TraceStroke.fromSvg(String svg) {
    final proxy = _PathBuilder();
    writeSvgPathDataToPath(svg, proxy);
    final metric = proxy.path.computeMetrics().first;
    final length = metric.length;
    if (length < dotLength) {
      final centre = metric.getTangentForOffset(length / 2)!.position;
      return TraceStroke._(proxy.path, [centre], [0], length);
    }
    final n = math.max(2, (length / spacing).ceil() + 1);
    final points = <Offset>[];
    final distances = <double>[];
    for (var i = 0; i < n; i++) {
      final d = length * i / (n - 1);
      points.add(metric.getTangentForOffset(d)!.position);
      distances.add(d);
    }
    return TraceStroke._(proxy.path, points, distances, length);
  }

  final Path path;
  final List<Offset> points;

  /// Distance along [path] of each checkpoint.
  final List<double> distances;
  final double length;

  bool get isDot => length < dotLength;
  Offset get start => points.first;

  /// The part of the stroke from its start to checkpoint [reached] - 1.
  Path partUpTo(int reached) {
    if (reached <= 0 || isDot) return Path();
    final d = distances[math.min(reached, points.length) - 1];
    return path.computeMetrics().first.extractPath(0, d);
  }

  /// Direction of travel at the start (unit vector), for the arrow.
  Offset get startDirection {
    if (points.length < 3) return const Offset(0, 1);
    final v = points[2] - points[0];
    return v / v.distance;
  }
}

/// A letter or number to trace: its strokes in writing order, and the
/// area (in shape units) the screen should show.
class TraceShape {
  TraceShape._(this.strokes, this.view, this.kind);

  factory TraceShape.fromSvgs(List<String> svgs, TraceKind kind) {
    final strokes = [for (final s in svgs) TraceStroke.fromSvg(s)];
    var minX = double.infinity;
    var maxX = -double.infinity;
    for (final s in strokes) {
      final b = s.path.getBounds();
      minX = math.min(minX, b.left);
      maxX = math.max(maxX, b.right);
    }
    // Always show the full writing lines, so every letter of a set
    // appears at the same size and height.
    final bottom = kind == TraceKind.lower ? TraceLines.tail : TraceLines.base;
    final view = Rect.fromLTRB(minX, TraceLines.top, maxX, bottom).inflate(margin);
    return TraceShape._(strokes, view, kind);
  }

  /// Room around the shape for the thick guide line and the start dot.
  static const margin = 16.0;

  final List<TraceStroke> strokes;
  final Rect view;
  final TraceKind kind;
}

class _PathBuilder extends PathProxy {
  final Path path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}
