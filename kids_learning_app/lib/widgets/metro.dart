import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../app/theme.dart';
import 'bouncy.dart';

/// Metro-style (Windows Phone) tile layout.
///
/// The grid measures the space it actually has, picks a column count
/// (4 on phones, 6 or 8 on tablets) and makes square cells. Each tile
/// spans [MetroTileSpec.w] x [MetroTileSpec.h] cells. Tiles are given by a
/// builder so their spans can change with the column count.
class MetroTileSpec {
  const MetroTileSpec({required this.w, required this.h, required this.child});

  final int w;
  final int h;
  final Widget child;
}

class MetroGrid extends StatelessWidget {
  const MetroGrid({super.key, required this.tiles, this.gap = 10});

  final List<MetroTileSpec> Function(int columns) tiles;
  final double gap;

  /// Smallest even column count that suits the width, raised until a
  /// 2-cell-tall tile fits the height (so short landscape phones still
  /// show the main tiles without scrolling).
  static int columnsFor(Size size, double gap) {
    var cols = size.width < 600 ? 4 : (size.width < 1000 ? 6 : 8);
    double unit(int c) => (size.width - gap * (c - 1)) / c;
    while (cols < 10 && size.height.isFinite && unit(cols) * 2 + gap > size.height) {
      cols += 2;
    }
    return cols;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = columnsFor(Size(c.maxWidth, c.maxHeight), gap);
        final specs = tiles(cols);
        return SingleChildScrollView(
          child: StaggeredGrid.count(
            crossAxisCount: cols,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            children: [
              for (final t in specs)
                StaggeredGridTile.count(
                  crossAxisCellCount: t.w.clamp(1, cols).toInt(),
                  mainAxisCellCount: t.h,
                  child: t.child,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One flat Metro tile: solid colour, content in the middle, label at the
/// bottom-left. Text sizes follow the tile's own size.
class MetroTile extends StatelessWidget {
  const MetroTile({
    super.key,
    required this.color,
    required this.label,
    required this.child,
    this.onTap,
    this.labelColor = Colors.white,
    this.semanticLabel,
  });

  final Color color;
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final Color labelColor;
  final String? semanticLabel;

  static const radius = 12.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticLabel ?? label,
      child: Bouncy(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, c) {
            final side = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
            final pad = (side * 0.08).clamp(8.0, 20.0).toDouble();
            final labelSize = (side * 0.13).clamp(14.0, 30.0).toDouble();
            return Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(radius),
              ),
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Center(child: child)),
                  if (label.isNotEmpty) ...[
                    SizedBox(height: pad * 0.4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: baloo(labelSize, weight: 700, color: labelColor, height: 1.1),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
