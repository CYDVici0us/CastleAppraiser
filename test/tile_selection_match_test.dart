import 'dart:ui';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/tile_selection_geom.dart';
import 'package:btcc/src/tflite/tile_selection_match.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:test/test.dart';

TfliteProcessedGuess g({
  required TileLabels label,
  required double x,
  required double y,
  double w = 90,
  double h = 80,
  double score = 0.9,
}) {
  return TfliteProcessedGuess(
    xMin: x,
    xMax: x + w,
    yMin: y,
    yMax: y + h,
    label: label,
    probability: score,
    confidence: 1,
    score: score,
  );
}

void main() {
  const cal = TileSelectionCalibration(
    imagePath: 'x.jpg',
    throneRect: Rect.fromLTWH(400, 400, 200, 80),
    boundsRect: Rect.fromLTWH(0, 0, 2000, 1600),
  );

  test('assignGuessesToMarkedCells maps room centers onto marked cells', () {
    final marked = {
      const GridCell(0, 0),
      const GridCell(1, 0),
      const GridCell(-1, 0),
      const GridCell(0, -1),
    };
    final assigned = assignGuessesToMarkedCells(
      guesses: [
        g(label: TileLabels.TRCD, x: 400, y: 400, w: 200, h: 80),
        g(label: TileLabels.KITCHEN, x: 305, y: 405),
        g(label: TileLabels.LOFT, x: 405, y: 325),
      ],
      marked: marked,
      calibration: cal,
    );
    expect(assigned[const GridCell(0, 0)]?.label, TileLabels.TRCD);
    expect(assigned[const GridCell(-1, 0)]?.label, TileLabels.KITCHEN);
    expect(assigned[const GridCell(0, -1)]?.label, TileLabels.LOFT);
    expect(assigned.containsKey(const GridCell(1, 0)), isFalse);
  });

  test('pickGuessForCell prefers the nearest room tile', () {
    final picked = pickGuessForCell(
      [
        g(label: TileLabels.KITCHEN, x: 200, y: 400),
        g(label: TileLabels.LOFT, x: 300, y: 400),
      ],
      const GridCell(-1, 0),
      cal,
    );
    expect(picked?.label, TileLabels.LOFT);
  });
}
