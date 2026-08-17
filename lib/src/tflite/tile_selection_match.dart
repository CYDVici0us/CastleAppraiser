import 'dart:math' as math;
import 'dart:ui';

import 'package:btcc/src/tflite/tile_selection_geom.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';

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

  for (final g in ranked) {
    if (TfliteHelper.isNonTile(g) || TfliteHelper.isThroneRoom(g)) continue;
    final cx = (g.xMin + g.xMax) / 2;
    final cy = (g.yMin + g.yMax) / 2;
    final cell = calibration.cellAtImagePoint(
      Offset(cx, cy),
      requireInBounds: false,
    );
    if (cell == null || !marked.contains(cell)) continue;
    if (cell.isThroneOrPlaceholder) continue;
    assigned.putIfAbsent(cell, () => g);
  }
  return assigned;
}

/// Closest detection to [cell], within ~0.65 tile of the cell center.
TfliteProcessedGuess? pickGuessForCell(
  List<TfliteProcessedGuess> guesses,
  GridCell cell,
  TileSelectionCalibration calibration,
) {
  if (cell.x == 1 && cell.y == 0) return null;
  final target = calibration.cellCenter(cell);
  final maxDist =
      math.max(calibration.tileWidth, calibration.tileHeight) * 0.65;
  TfliteProcessedGuess? best;
  var bestDist = maxDist;
  for (final g in guesses) {
    if (cell.x == 0 && cell.y == 0) {
      if (!TfliteHelper.isThroneRoom(g)) continue;
    } else if (TfliteHelper.isNonTile(g) || TfliteHelper.isThroneRoom(g)) {
      continue;
    }
    final cx = (g.xMin + g.xMax) / 2;
    final cy = (g.yMin + g.yMax) / 2;
    final dist = math.sqrt(
      math.pow(cx - target.dx, 2) + math.pow(cy - target.dy, 2),
    );
    if (dist < bestDist) {
      best = g;
      bestDist = dist;
    }
  }
  return best;
}
