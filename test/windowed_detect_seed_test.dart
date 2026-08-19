import 'dart:ui';

import 'package:btcc/src/tflite/tile_selection_geom.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:btcc/src/tflite/windowed_detect.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:test/test.dart';

TfliteProcessedGuess g({
  required TileLabels label,
  required double xMin,
  required double yMin,
  required double w,
  required double h,
  double score = 0.9,
}) {
  return TfliteProcessedGuess(
    xMin: xMin,
    xMax: xMin + w,
    yMin: yMin,
    yMax: yMin + h,
    label: label,
    probability: score,
    confidence: 1,
    score: score,
  );
}

void main() {
  test('seedMarkedCells marks upper cells with looser center coverage', () {
    const cal = TileSelectionCalibration(
      imagePath: 'x.jpg',
      throneRect: Rect.fromLTWH(400, 400, 200, 80),
      boundsRect: Rect.fromLTWH(0, 0, 2000, 1600),
    );

    final top = const GridCell(0, -1);
    final bottom = const GridCell(0, 1);

    // Cell area = 100*100 = 10000 (square cells).
    // Guess intersection area = 80*25 = 2000 => coverage=0.2.
    const xMin = 410.0;
    const w = 80.0;
    const h = 25.0;

    // Fits inside top cell (y=-1): top cell rect is y=300..400.
    const topYMin = 330.0; // 330..355
    // Fits inside bottom cell (y=1): bottom cell rect is y=500..600.
    const bottomYMin = 530.0; // 530..555

    final guesses = [
      g(label: TileLabels.KITCHEN, xMin: xMin, yMin: topYMin, w: w, h: h),
      g(
        label: TileLabels.KITCHEN,
        xMin: xMin,
        yMin: bottomYMin,
        w: w,
        h: h,
      ),
    ];

    final seeded = WindowedDetect.seedMarkedCells(
      guesses: guesses,
      calibration: cal,
      alwaysMarked: {const GridCell(0, 0), const GridCell(1, 0)},
    );

    expect(seeded.contains(top), isTrue);
    expect(seeded.contains(bottom), isFalse);
  });
}

