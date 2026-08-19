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

  /// Pairwise pitch estimates outside this band of the current size are noise.
  static const double minPairwiseScale = 0.55;
  static const double maxPairwiseScale = 1.45;

  /// Applied scale vs the throne box is clamped so one bad wing cannot flip the grid.
  static const double minAppliedScale = 0.80;
  static const double maxAppliedScale = 1.20;

  static const int minPairwiseSamples = 3;

  /// Castles are wide but short (often 2–4 rows), so fewer vertical pairs
  /// are available than horizontal ones.
  static const int minPairwiseSamplesVertical = 2;

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

  /// Refine tile size from pairwise room-center gaps, then nudge origin.
  ///
  /// A fat throne box makes `tileW` too large, so far-west rooms bin one cell
  /// closer to the throne (Castle 4 Firewood on Meditation). Median pairwise
  /// pitch from several rooms is robust to a few wrong bins.
  ThroneAnchoredLattice refinePitch({
    required Iterable<(int gx, int gy, double cx, double cy)> samples,
  }) {
    final list = samples.toList();
    if (list.isEmpty) return this;

    final xPitch = medianPairwisePitch(
      list.map((s) => (s.$1, s.$3)),
      currentPitch: tileW,
    );
    final yPitch = medianPairwisePitch(
      list.map((s) => (s.$2, s.$4)),
      currentPitch: tileH,
      minSamples: minPairwiseSamplesVertical,
    );

    var next = this;
    if (xPitch != null || yPitch != null) {
      next = next._withScaleKeepingThroneCenter(
        tileW: xPitch ?? tileW,
        tileH: yPitch ?? tileH,
      );
    }
    return next._nudgeOrigin(list);
  }

  /// Median of (coord_j - coord_i) / (index_j - index_i) for distinct bins.
  static double? medianPairwisePitch(
    Iterable<(int index, double coord)> samples, {
    required double currentPitch,
    int? minSamples,
  }) {
    if (currentPitch <= 0) return null;
    final list = samples.toList();
    final pitches = <double>[];
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final dg = list[j].$1 - list[i].$1;
        if (dg.abs() < 1) continue;
        final pitch = (list[j].$2 - list[i].$2) / dg;
        if (pitch <= 0) continue;
        final scale = pitch / currentPitch;
        if (scale < minPairwiseScale || scale > maxPairwiseScale) continue;
        pitches.add(pitch);
      }
    }
    if (pitches.length < (minSamples ?? minPairwiseSamples)) return null;
    pitches.sort();
    return _clampPitch(pitches[pitches.length ~/ 2], currentPitch);
  }

  static double _clampPitch(double estimated, double current) {
    final lo = current * minAppliedScale;
    final hi = current * maxAppliedScale;
    return estimated.clamp(lo, hi).toDouble();
  }

  /// Keep the 2-wide throne's center (and the throne-row vertical center).
  ThroneAnchoredLattice _withScaleKeepingThroneCenter({
    required double tileW,
    required double tileH,
  }) {
    final nextW = math.max(tileW, 1.0);
    final nextH = math.max(tileH, 1.0);
    return ThroneAnchoredLattice(
      originX: originX + this.tileW - nextW,
      originY: originY + 0.5 * this.tileH - 0.5 * nextH,
      tileW: nextW,
      tileH: nextH,
    );
  }

  ThroneAnchoredLattice _nudgeOrigin(
    List<(int gx, int gy, double cx, double cy)> samples,
  ) {
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
    return ThroneAnchoredLattice(
      originX: originX + dx[dx.length ~/ 2],
      originY: originY + dy[dy.length ~/ 2],
      tileW: tileW,
      tileH: tileH,
    );
  }
}
