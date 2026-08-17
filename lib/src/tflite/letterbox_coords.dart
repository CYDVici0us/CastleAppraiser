import 'dart:math' as math;

/// Geometry for the detector preprocess: pad-to-square → resize → CW rotates.
class LetterboxGeom {
  final int srcW;
  final int srcH;
  final int padSize;
  final int ox;
  final int oy;
  final int inputSize;
  final int rotations;

  const LetterboxGeom({
    required this.srcW,
    required this.srcH,
    required this.padSize,
    required this.ox,
    required this.oy,
    required this.inputSize,
    required this.rotations,
  });

  factory LetterboxGeom.fromSource({
    required int srcW,
    required int srcH,
    required int inputSize,
    required int rotations,
  }) {
    // Never upscale a small crop to fill the model: pad to at least
    // [inputSize] so a single tile stays near training scale.
    final padSize = math.max(math.max(srcW, srcH) + 1, inputSize);
    return LetterboxGeom(
      srcW: srcW,
      srcH: srcH,
      padSize: padSize,
      ox: ((padSize - srcW) / 2).floor(),
      oy: ((padSize - srcH) / 2).floor(),
      inputSize: inputSize,
      rotations: rotations % 4,
    );
  }
}

/// Map a point from model input space (after CW [rotations]) back to the
/// unpadded source bitmap.
(double, double) undoLetterboxPoint(
  double mx,
  double my,
  LetterboxGeom g,
) {
  var x = mx;
  var y = my;
  var w = g.inputSize.toDouble();
  var h = g.inputSize.toDouble();
  for (var i = 0; i < g.rotations; i++) {
    // Inverse of one 90° CW on a w×h image.
    final nx = y;
    final ny = w - x;
    x = nx;
    y = ny;
    final nw = h;
    final nh = w;
    w = nw;
    h = nh;
  }
  // Undo resize padSize → inputSize.
  final px = x * g.padSize / g.inputSize;
  final py = y * g.padSize / g.inputSize;
  return (px - g.ox, py - g.oy);
}

/// Axis-aligned box corners through [undoLetterboxPoint], then AABB + clamp.
({double xMin, double xMax, double yMin, double yMax}) undoLetterboxBox({
  required double xMin,
  required double xMax,
  required double yMin,
  required double yMax,
  required LetterboxGeom g,
}) {
  final corners = <(double, double)>[
    undoLetterboxPoint(xMin, yMin, g),
    undoLetterboxPoint(xMax, yMin, g),
    undoLetterboxPoint(xMin, yMax, g),
    undoLetterboxPoint(xMax, yMax, g),
  ];
  var minX = double.infinity;
  var maxX = double.negativeInfinity;
  var minY = double.infinity;
  var maxY = double.negativeInfinity;
  for (final (x, y) in corners) {
    minX = math.min(minX, x);
    maxX = math.max(maxX, x);
    minY = math.min(minY, y);
    maxY = math.max(maxY, y);
  }
  minX = minX.clamp(0.0, g.srcW.toDouble());
  maxX = maxX.clamp(0.0, g.srcW.toDouble());
  minY = minY.clamp(0.0, g.srcH.toDouble());
  maxY = maxY.clamp(0.0, g.srcH.toDouble());
  return (xMin: minX, xMax: maxX, yMin: minY, yMax: maxY);
}
