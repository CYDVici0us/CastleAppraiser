import 'dart:ui';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/tile_selection_geom.dart';
import 'package:btcc/src/tflite/tile_selection_match.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
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

  test('token guesses are collected even when not assigned to room cells', () {
    final guesses = [
      g(label: TileLabels.TRCD, x: 400, y: 400, w: 200, h: 80),
      g(label: TileLabels.RAM, x: 650, y: 410, w: 60, h: 60),
      g(label: TileLabels.BCREGULAR, x: 40, y: 360, w: 70, h: 120),
      g(label: TileLabels.KITCHEN, x: 305, y: 405),
    ];
    final assigned = assignGuessesToMarkedCells(
      guesses: guesses,
      marked: {
        const GridCell(0, 0),
        const GridCell(1, 0),
        const GridCell(-1, 0),
      },
      calibration: cal,
    );
    expect(assigned[const GridCell(-1, 0)]?.label, TileLabels.KITCHEN);
    final tokens = TfliteHelper.collectTokenTiles(guesses);
    expect(tokens.where((t) => t.isRoyalAttendant()).length, 1);
    expect(tokens.where((t) => t.isBonusCard()).length, 1);
  });

  test('pickGuessForCell prefers the box that covers the cell', () {
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

  test('pickGuessForCell does not steal a neighbor via nearest-center', () {
    final picked = pickGuessForCell(
      [
        g(label: TileLabels.KITCHEN, x: 305, y: 405),
      ],
      const GridCell(2, 0),
      cal,
      marked: {
        const GridCell(0, 0),
        const GridCell(1, 0),
        const GridCell(-1, 0),
        const GridCell(2, 0),
      },
    );
    expect(picked, isNull);
  });

  test('assignGuessesToMarkedCells puts a unique room on the better-covered cell', () {
    final marked = {
      const GridCell(0, 0),
      const GridCell(1, 0),
      const GridCell(-1, 0),
      const GridCell(2, 0),
    };
    // Kitchen box sits on the west cell, not the far east cell.
    final assigned = assignGuessesToMarkedCells(
      guesses: [
        g(label: TileLabels.TRCD, x: 400, y: 400, w: 200, h: 80),
        g(label: TileLabels.KITCHEN, x: 305, y: 405, score: 0.95),
      ],
      marked: marked,
      calibration: cal,
    );
    expect(assigned[const GridCell(-1, 0)]?.label, TileLabels.KITCHEN);
    expect(assigned.containsKey(const GridCell(2, 0)), isFalse);
  });

  test('assignGuessesToMarkedCells uses box coverage not just center', () {
    final marked = {
      const GridCell(0, 0),
      const GridCell(1, 0),
      const GridCell(-1, 0),
    };
    // Box straddles the west cell and the throne; center is on the throne edge.
    final assigned = assignGuessesToMarkedCells(
      guesses: [
        g(label: TileLabels.TRCD, x: 400, y: 400, w: 200, h: 80),
        g(label: TileLabels.KITCHEN, x: 350, y: 400, w: 100, h: 80),
      ],
      marked: marked,
      calibration: cal,
    );
    expect(assigned[const GridCell(-1, 0)]?.label, TileLabels.KITCHEN);
  });

  test('assignGuessesToMarkedCells keeps only one unique Kitchen', () {
    final marked = {
      const GridCell(0, 0),
      const GridCell(1, 0),
      const GridCell(-1, 0),
      const GridCell(2, 0),
    };
    final assigned = assignGuessesToMarkedCells(
      guesses: [
        g(label: TileLabels.TRCD, x: 400, y: 400, w: 200, h: 80),
        g(label: TileLabels.KITCHEN, x: 305, y: 405, score: 0.95),
        g(label: TileLabels.KITCHEN, x: 605, y: 405, score: 0.6),
        g(label: TileLabels.LOFT, x: 605, y: 405, score: 0.55),
      ],
      marked: marked,
      calibration: cal,
    );
    final kitchens = assigned.values
        .where((g) => g.label == TileLabels.KITCHEN)
        .length;
    expect(kitchens, 1);
    expect(assigned[const GridCell(-1, 0)]?.label, TileLabels.KITCHEN);
    expect(assigned[const GridCell(2, 0)]?.label, TileLabels.LOFT);
  });

  test('coverageOfCell is high when the box fills the cell', () {
    final cov = coverageOfCell(
      g(label: TileLabels.KITCHEN, x: 300, y: 400, w: 100, h: 100),
      const GridCell(-1, 0),
      cal,
    );
    expect(cov, greaterThan(0.9));
  });

  test('assignGuessesToMarkedCells skips a unique room that straddles two cells', () {
    final marked = {
      const GridCell(0, 0),
      const GridCell(1, 0),
      const GridCell(-2, 0),
      const GridCell(-1, 0),
    };
    final assigned = assignGuessesToMarkedCells(
      guesses: [
        g(label: TileLabels.TRCD, x: 400, y: 400, w: 200, h: 80),
        g(label: TileLabels.KITCHEN, x: 255, y: 400, w: 100, h: 80),
      ],
      marked: marked,
      calibration: cal,
    );
    expect(assigned[const GridCell(-2, 0)], isNull);
    expect(assigned[const GridCell(-1, 0)], isNull);
  });

  test('refineCalibrationFromGuesses recovers a west-wing cell from a fat throne', () {
    const fat = TileSelectionCalibration(
      imagePath: 'x.jpg',
      throneRect: Rect.fromLTWH(380, 400, 240, 80),
      boundsRect: Rect.fromLTWH(0, 0, 2000, 1600),
    );
    expect(
      fat.cellAtImagePoint(const Offset(50, 440), requireInBounds: false),
      const GridCell(-3, 0),
    );

    final refined = refineCalibrationFromGuesses(fat, [
      g(label: TileLabels.TRCF, x: 380, y: 400, w: 240, h: 80),
      g(label: TileLabels.FIREWOOD_STORAGE, x: 5, y: 400, w: 90, h: 80),
      g(label: TileLabels.TERRACE, x: 205, y: 400, w: 90, h: 80),
      g(label: TileLabels.LOUNGE, x: 305, y: 400, w: 90, h: 80),
      g(label: TileLabels.AMONG_THE_CURTAINS, x: 605, y: 400, w: 90, h: 80),
      g(label: TileLabels.TAPESTRY_ROOM, x: 705, y: 400, w: 90, h: 80),
    ]);
    expect(
      refined.cellAtImagePoint(const Offset(50, 440), requireInBounds: false),
      const GridCell(-4, 0),
    );
  });
}
