import 'dart:collection';

import 'package:btcc/src/tflite/throne_anchored_lattice.dart';

/// Occupancy helpers for scan/grid shape reconstruction.
class CastleOccupancy {
  CastleOccupancy._();

  /// 4-connected cells reachable from [start] through [occupied].
  static Set<(int, int)> connectedComponent({
    required (int, int) start,
    required Set<(int, int)> occupied,
  }) {
    if (!occupied.contains(start)) return {start};
    final seen = <(int, int)>{start};
    final q = Queue<(int, int)>()..add(start);
    while (q.isNotEmpty) {
      final (x, y) = q.removeFirst();
      for (final n in _neighbors4(x, y)) {
        if (occupied.contains(n) && seen.add(n)) {
          q.add(n);
        }
      }
    }
    return seen;
  }

  /// Drop [cells] not in the throne-connected component.
  static Set<(int, int)> pruneDisconnected({
    required Set<(int, int)> cells,
    required (int, int) throneCell,
  }) {
    if (cells.isEmpty) return cells;
    final throneStart = cells.contains(throneCell)
        ? throneCell
        : cells.contains((0, 0))
            ? (0, 0)
            : cells.first;
    return connectedComponent(start: throneStart, occupied: cells);
  }

  /// Fill empty cells fully surrounded by occupied (4-neighbor closing).
  static Set<(int, int)> morphologicalClosing(Set<(int, int)> occupied) {
    var current = Set<(int, int)>.from(occupied);
    var changed = true;
    while (changed) {
      changed = false;
      var minX = current.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
      var maxX = current.map((c) => c.$1).reduce((a, b) => a > b ? a : b);
      var minY = current.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
      var maxY = current.map((c) => c.$2).reduce((a, b) => a > b ? a : b);
      for (var y = minY; y <= maxY; y++) {
        for (var x = minX; x <= maxX; x++) {
          final cell = (x, y);
          if (current.contains(cell)) continue;
          final neighbors = _neighbors4(x, y)
              .where((n) => current.contains(n))
              .length;
          if (neighbors >= 4) {
            current.add(cell);
            changed = true;
          }
        }
      }
    }
    return current;
  }

  static Iterable<(int, int)> _neighbors4(int x, int y) sync* {
    yield (x - 1, y);
    yield (x + 1, y);
    yield (x, y - 1);
    yield (x, y + 1);
  }

  /// Map relative lattice cells to grid indices (row 0 = top / smallest gy).
  static ({
    int width,
    int height,
    int minGx,
    int minGy,
    int Function(int gx, int gy) toIndex,
  }) gridLayout(Set<(int, int)> relativeCells) {
    if (relativeCells.isEmpty) {
      return (
        width: 4,
        height: 3,
        minGx: 0,
        minGy: 0,
        toIndex: (_, __) => 0,
      );
    }
    var minGx = relativeCells.first.$1;
    var maxGx = relativeCells.first.$1;
    var minGy = relativeCells.first.$2;
    var maxGy = relativeCells.first.$2;
    for (final (gx, gy) in relativeCells) {
      if (gx < minGx) minGx = gx;
      if (gx > maxGx) maxGx = gx;
      if (gy < minGy) minGy = gy;
      if (gy > maxGy) maxGy = gy;
    }
    // Margin for token strip / padding.
    final pad = 1;
    minGx -= pad;
    minGy -= pad;
    maxGx += pad;
    maxGy += pad;
    final width = maxGx - minGx + 1;
    final height = maxGy - minGy + 1;
    int toIndex(int gx, int gy) {
      final col = gx - minGx;
      final row = gy - minGy;
      return row * width + col;
    }
    return (
      width: width,
      height: height,
      minGx: minGx,
      minGy: minGy,
      toIndex: toIndex,
    );
  }

  static double coverageOfCell({
    required ThroneAnchoredLattice lattice,
    required int gx,
    required int gy,
    required double xMin,
    required double xMax,
    required double yMin,
    required double yMax,
  }) {
    final left = lattice.originX + gx * lattice.tileW;
    final top = lattice.originY + gy * lattice.tileH;
    final right = left + lattice.tileW;
    final bottom = top + lattice.tileH;
    if (gx == 0 && gy == 0) {
      // Throne strip is 2-wide.
      final rRight = left + lattice.tileW * 2;
      return _rectCoverage(
        left,
        top,
        rRight,
        bottom,
        xMin,
        yMin,
        xMax,
        yMax,
      );
    }
    return _rectCoverage(left, top, right, bottom, xMin, yMin, xMax, yMax);
  }

  static double _rectCoverage(
    double rLeft,
    double rTop,
    double rRight,
    double rBottom,
    double xMin,
    double yMin,
    double xMax,
    double yMax,
  ) {
    final ixMin = xMin > rLeft ? xMin : rLeft;
    final ixMax = xMax < rRight ? xMax : rRight;
    final iyMin = yMin > rTop ? yMin : rTop;
    final iyMax = yMax < rBottom ? yMax : rBottom;
    final w = ixMax - ixMin;
    final h = iyMax - iyMin;
    if (w <= 0 || h <= 0) return 0;
    final area = (rRight - rLeft) * (rBottom - rTop);
    if (area <= 0) return 0;
    return (w * h) / area;
  }
}
