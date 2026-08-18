import 'dart:math' as math;

import 'package:btcc/src/tflite/tile_selection_geom.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';

/// Minimum fraction of a grid cell that a detection box must cover.
const double kMinCellCoverage = 0.28;

/// Fraction of [cell] covered by [guess] (intersection / cell area).
double coverageOfCell(
  TfliteProcessedGuess guess,
  GridCell cell,
  TileSelectionCalibration calibration,
) {
  final r = (cell.x == 0 && cell.y == 0)
      ? calibration.throneStrip()
      : calibration.cellRect(cell);
  final xMin = math.max(guess.xMin, r.left);
  final xMax = math.min(guess.xMax, r.right);
  final yMin = math.max(guess.yMin, r.top);
  final yMax = math.min(guess.yMax, r.bottom);
  final w = xMax - xMin;
  final h = yMax - yMin;
  if (w <= 0 || h <= 0) return 0;
  final area = r.width * r.height;
  if (area <= 0) return 0;
  return (w * h) / area;
}

/// Map full-castle detections onto user-marked grid cells.
Map<GridCell, TfliteProcessedGuess> assignGuessesToMarkedCells({
  required List<TfliteProcessedGuess> guesses,
  required Set<GridCell> marked,
  required TileSelectionCalibration calibration,
}) {
  final assigned = <GridCell, TfliteProcessedGuess>{};
  final ranked = List<TfliteProcessedGuess>.from(guesses)
    ..sort((a, b) => b.score.compareTo(a.score));

  for (final g in ranked.where(TfliteHelper.isThroneRoom)) {
    if (!marked.contains(const GridCell(0, 0))) break;
    assigned[const GridCell(0, 0)] = g;
    break;
  }

  final usedCopies = <Object, int>{};
  for (final g in ranked) {
    if (TfliteHelper.isNonTile(g) || TfliteHelper.isThroneRoom(g)) continue;
    final already = usedCopies[g.label] ?? 0;
    if (already >= TfliteHelper.maxCopiesForLabel(g.label)) continue;
    GridCell? bestCell;
    var bestCov = kMinCellCoverage;
    for (final cell in marked) {
      if (cell.isThroneOrPlaceholder) continue;
      if (assigned.containsKey(cell)) continue;
      final cov = coverageOfCell(g, cell, calibration);
      if (cov > bestCov) {
        bestCov = cov;
        bestCell = cell;
      }
    }
    if (bestCell != null) {
      assigned[bestCell] = g;
      usedCopies[g.label] = already + 1;
    }
  }
  return assigned;
}

/// Best detection for [cell]: prefers coverage of the cell rect, then proximity.
TfliteProcessedGuess? pickGuessForCell(
  List<TfliteProcessedGuess> guesses,
  GridCell cell,
  TileSelectionCalibration calibration, {
  Map<Object, int> usedCopies = const {},
}) {
  if (cell.x == 1 && cell.y == 0) return null;
  final target = calibration.cellCenter(cell);
  final maxDist =
      math.max(calibration.tileWidth, calibration.tileHeight) * 0.85;

  TfliteProcessedGuess? bestCovered;
  var bestCoveredKey = -1.0;
  TfliteProcessedGuess? bestNear;
  var bestDist = maxDist;

  for (final g in guesses) {
    if (cell.x == 0 && cell.y == 0) {
      if (!TfliteHelper.isThroneRoom(g)) continue;
    } else if (TfliteHelper.isNonTile(g) || TfliteHelper.isThroneRoom(g)) {
      continue;
    }
    final already = usedCopies[g.label] ?? 0;
    if (already >= TfliteHelper.maxCopiesForLabel(g.label)) continue;
    final cov = coverageOfCell(g, cell, calibration);
    if (cov >= kMinCellCoverage) {
      final key = cov + g.score * 0.01;
      if (key > bestCoveredKey) {
        bestCoveredKey = key;
        bestCovered = g;
      }
    }
    final cx = (g.xMin + g.xMax) / 2;
    final cy = (g.yMin + g.yMax) / 2;
    final dist = math.sqrt(
      math.pow(cx - target.dx, 2) + math.pow(cy - target.dy, 2),
    );
    if (dist < bestDist) {
      bestNear = g;
      bestDist = dist;
    }
  }
  return bestCovered ?? bestNear;
}
