import 'dart:math' as math;

import 'package:btcc/src/tflite/tflite_objects.dart';

/// Image-space grid anchored on the left cell of the 2-wide throne (gy=0 ground row).
class ThroneAnchoredLattice {
  final double originX;
  final double originY;
  final double tileW;
  final double tileH;

  const ThroneAnchoredLattice({
    required this.originX,
    required this.originY,
    required this.tileW,
    required this.tileH,
  });

  factory ThroneAnchoredLattice.fromThroneBox({
    required double xMin,
    required double yMin,
    required double xMax,
    required double yMax,
  }) {
    final w = xMax - xMin;
    final h = yMax - yMin;
    return ThroneAnchoredLattice(
      originX: xMin,
      originY: yMin,
      tileW: math.max(w / 2.0, 1),
      tileH: math.max(h, 1),
    );
  }

  factory ThroneAnchoredLattice.fromGuess(TfliteProcessedGuess throne) {
    return ThroneAnchoredLattice.fromThroneBox(
      xMin: throne.xMin,
      yMin: throne.yMin,
      xMax: throne.xMax,
      yMax: throne.yMax,
    );
  }

  /// Relative grid cell (gx, gy); throne left = (0,0), placeholder = (1,0).
  (int gx, int gy) cellForCenter(double cx, double cy) {
    final gx = ((cx - originX) / tileW).floor();
    final gy = ((cy - originY) / tileH).floor();
    return (gx, gy);
  }

  (int gx, int gy) cellForGuess(TfliteProcessedGuess g) {
    final cx = (g.xMin + g.xMax) / 2;
    final cy = (g.yMin + g.yMax) / 2;
    return cellForCenter(cx, cy);
  }

  /// Nudge pitch from median residual of room centers vs integer lattice.
  ThroneAnchoredLattice refinePitch({
    required Iterable<(int gx, int gy, double cx, double cy)> samples,
  }) {
    if (samples.isEmpty) return this;
    final dx = <double>[];
    final dy = <double>[];
    for (final s in samples) {
      final expectedCx = originX + (s.$1 + 0.5) * tileW;
      final expectedCy = originY + (s.$2 + 0.5) * tileH;
      dx.add(s.$3 - expectedCx);
      dy.add(s.$4 - expectedCy);
    }
    dx.sort();
    dy.sort();
    final medDx = dx[dx.length ~/ 2];
    final medDy = dy[dy.length ~/ 2];
    return ThroneAnchoredLattice(
      originX: originX + medDx,
      originY: originY + medDy,
      tileW: tileW,
      tileH: tileH,
    );
  }
}
