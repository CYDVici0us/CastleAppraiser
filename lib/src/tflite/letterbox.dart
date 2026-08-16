import 'dart:math' as math;

/// Geometry helpers for letterbox pad → resize → rotate preprocess used by
/// [TfliteDetector]. Kept separate so mapping can be unit-tested without TFLite.
class LetterboxGeometry {
  final int imageWidth;
  final int imageHeight;
  final int padSize;
  final int ox;
  final int oy;

  const LetterboxGeometry({
    required this.imageWidth,
    required this.imageHeight,
    required this.padSize,
    required this.ox,
    required this.oy,
  });

  factory LetterboxGeometry.fromImageSize(int width, int height) {
    final padSize = math.max(width, height) + 1;
    return LetterboxGeometry(
      imageWidth: width,
      imageHeight: height,
      padSize: padSize,
      ox: ((padSize - width) / 2).floor(),
      oy: ((padSize - height) / 2).floor(),
    );
  }
}

class MappedBox {
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final bool valid;

  const MappedBox({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.valid,
  });
}

/// Maps a model-space axis-aligned box back to original image pixels.
///
/// Preprocess order is pad → resize to [inputImageSize] → rotate CW [rotations]
/// times, so undo is unrotate → unscale → unpad, then clamp to image bounds.
MappedBox mapModelBoxToImage({
  required double xMin,
  required double xMax,
  required double yMin,
  required double yMax,
  required int inputImageSize,
  required int rotations,
  required LetterboxGeometry geometry,
}) {
  final s = inputImageSize.toDouble();
  var corners = <List<double>>[
    [xMin, yMin],
    [xMax, yMin],
    [xMin, yMax],
    [xMax, yMax],
  ];

  // Undo CW rotations with CCW: (x, y) → (y, s - x).
  final turns = rotations % 4;
  for (var r = 0; r < turns; r++) {
    corners = [
      for (final c in corners) [c[1], s - c[0]],
    ];
  }

  var mx0 = corners[0][0];
  var mx1 = corners[0][0];
  var my0 = corners[0][1];
  var my1 = corners[0][1];
  for (final c in corners) {
    mx0 = math.min(mx0, c[0]);
    mx1 = math.max(mx1, c[0]);
    my0 = math.min(my0, c[1]);
    my1 = math.max(my1, c[1]);
  }

  final scale = geometry.padSize / s;
  var oxMin = mx0 * scale - geometry.ox;
  var oxMax = mx1 * scale - geometry.ox;
  var oyMin = my0 * scale - geometry.oy;
  var oyMax = my1 * scale - geometry.oy;

  final w = geometry.imageWidth.toDouble();
  final h = geometry.imageHeight.toDouble();

  // Soft edge handling: clamp overhang instead of rejecting near-edge boxes.
  oxMin = oxMin.clamp(0.0, w);
  oxMax = oxMax.clamp(0.0, w);
  oyMin = oyMin.clamp(0.0, h);
  oyMax = oyMax.clamp(0.0, h);

  final valid = oxMin < oxMax && oyMin < oyMax;
  return MappedBox(
    xMin: oxMin,
    xMax: oxMax,
    yMin: oyMin,
    yMax: oyMax,
    valid: valid,
  );
}
