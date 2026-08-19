import 'dart:math' as math;
import 'dart:ui';

import 'package:btcc/src/tflite/tile_selection_geom.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';

/// Minimum fraction of a grid cell that a detection box must cover.
///
/// Castle 3/4 scan goldens showed neighbor-stealing below this (coverage
/// ~0.10–0.22) which consumed unique rooms and left the true cell empty.
const double kMinCellCoverage = 0.28;

/// Second-best marked cell must cover at least this much to count as a rival.
const double kMinAmbiguousSecondCoverage = 0.18;

/// Best cell must beat the rival by this much coverage or the guess is skipped.
///
/// Castle 4 placed Firewood on Meditation when the same box overlapped both
/// west-wing cells. Leaving both unidentified is better than a unique-room shift.
const double kCoverageClearMargin = 0.18;

/// Autoseed only: lower threshold for the *center* point on cells above the
/// ground row (`gy < 0`).
///
/// Rationale:
/// - We want recall on the upper stack (Nap/Tower/Promenade) even when a box
///   only partially overlaps a lattice cell.
/// - We keep edge/corner-based marking at `kMinCellCoverage` to avoid the
///   "phantom tiles in empty space" false positives below the castle.
const double kAutoseedMinCenterCoverageTop = 0.18;

Rect _cellBounds(GridCell cell, TileSelectionCalibration calibration) {
  return (cell.x == 0 && cell.y == 0)
      ? calibration.throneStrip()
      : calibration.cellRect(cell);
}

double _intersectionArea(
  TfliteProcessedGuess guess,
  Rect r,
) {
  final xMin = math.max(guess.xMin, r.left);
  final xMax = math.min(guess.xMax, r.right);
  final yMin = math.max(guess.yMin, r.top);
  final yMax = math.min(guess.yMax, r.bottom);
  final w = xMax - xMin;
  final h = yMax - yMin;
  if (w <= 0 || h <= 0) return 0;
  return w * h;
}

/// Fraction of [cell] covered by [guess] (intersection / cell area).
double coverageOfCell(
  TfliteProcessedGuess guess,
  GridCell cell,
  TileSelectionCalibration calibration,
) {
  final r = _cellBounds(cell, calibration);
  final area = r.width * r.height;
  if (area <= 0) return 0;
  return _intersectionArea(guess, r) / area;
}

/// Intersection over union of [guess] and [cell].
double iouOfCell(
  TfliteProcessedGuess guess,
  GridCell cell,
  TileSelectionCalibration calibration,
) {
  final r = _cellBounds(cell, calibration);
  final inter = _intersectionArea(guess, r);
  if (inter <= 0) return 0;
  final box = math.max(0.0, guess.xMax - guess.xMin) *
      math.max(0.0, guess.yMax - guess.yMin);
  final union = r.width * r.height + box - inter;
  if (union <= 0) return 0;
  return inter / union;
}

bool coverageIsAmbiguous(double best, double second) {
  if (second < kMinAmbiguousSecondCoverage) return false;
  return (best - second) < kCoverageClearMargin;
}

/// Marked room cells this box overlaps, highest coverage first.
List<(GridCell cell, double coverage)> markedCellCoverages(
  TfliteProcessedGuess guess,
  Set<GridCell> marked,
  TileSelectionCalibration calibration, {
  Set<GridCell> skip = const {},
}) {
  final out = <(GridCell, double)>[];
  for (final cell in marked) {
    if (cell.isThroneOrPlaceholder) continue;
    if (skip.contains(cell)) continue;
    final cov = coverageOfCell(guess, cell, calibration);
    if (cov <= 0) continue;
    out.add((cell, cov));
  }
  out.sort((a, b) {
    final byCov = b.$2.compareTo(a.$2);
    if (byCov != 0) return byCov;
    return iouOfCell(guess, b.$1, calibration)
        .compareTo(iouOfCell(guess, a.$1, calibration));
  });
  return out;
}

/// Marked cell this box covers best, or null if none reach [kMinCellCoverage]
/// or two neighbors are too close to choose safely.
GridCell? bestCoveredMarkedCell(
  TfliteProcessedGuess guess,
  Set<GridCell> marked,
  TileSelectionCalibration calibration, {
  Set<GridCell> skip = const {},
}) {
  final ranks = markedCellCoverages(
    guess,
    marked,
    calibration,
    skip: skip,
  );
  if (ranks.isEmpty) return null;
  final best = ranks.first;
  if (best.$2 < kMinCellCoverage) return null;
  final second = ranks.length > 1 ? ranks[1].$2 : 0.0;
  if (coverageIsAmbiguous(best.$2, second)) return null;
  return best.$1;
}

/// Nudge the wizard throne box from room-center gaps (same idea as Scan lattice).
TileSelectionCalibration refineCalibrationFromGuesses(
  TileSelectionCalibration calibration,
  List<TfliteProcessedGuess> guesses,
) {
  final samples = <(int, int, double, double)>[];
  for (final g in guesses) {
    if (TfliteHelper.isNonTile(g) || TfliteHelper.isThroneRoom(g)) continue;
    final cx = (g.xMin + g.xMax) / 2;
    final cy = (g.yMin + g.yMax) / 2;
    final cell = calibration.cellAtImagePoint(
      Offset(cx, cy),
      requireInBounds: false,
    );
    if (cell == null || cell.isThroneOrPlaceholder) continue;
    samples.add((cell.x, cell.y, cx, cy));
  }
  return calibration.refinePitch(samples);
}

/// Map full-castle detections onto user-marked grid cells.
Map<GridCell, TfliteProcessedGuess> assignGuessesToMarkedCells({
  required List<TfliteProcessedGuess> guesses,
  required Set<GridCell> marked,
  required TileSelectionCalibration calibration,
  Map<GridCell, TfliteProcessedGuess>? already,
  Map<Object, int>? usedCopies,
}) {
  final assigned = <GridCell, TfliteProcessedGuess>{
    if (already != null) ...already,
  };
  final copies = <Object, int>{
    if (usedCopies != null) ...usedCopies,
  };
  final ranked = List<TfliteProcessedGuess>.from(guesses)
    ..sort((a, b) => b.score.compareTo(a.score));

  if (!assigned.containsKey(const GridCell(0, 0))) {
    for (final g in ranked.where(TfliteHelper.isThroneRoom)) {
      if (!marked.contains(const GridCell(0, 0))) break;
      assigned[const GridCell(0, 0)] = g;
      break;
    }
  }

  for (final g in ranked) {
    if (TfliteHelper.isNonTile(g) || TfliteHelper.isThroneRoom(g)) continue;
    final alreadyCount = copies[g.label] ?? 0;
    if (alreadyCount >= TfliteHelper.maxCopiesForLabel(g.label)) continue;
    final bestCell = bestCoveredMarkedCell(
      g,
      marked,
      calibration,
      skip: assigned.keys.toSet(),
    );
    if (bestCell != null) {
      assigned[bestCell] = g;
      copies[g.label] = alreadyCount + 1;
    }
  }
  return assigned;
}

/// Best detection for [cell] that actually covers this cell.
///
/// Does not fall back to "nearest box" — that stole unique rooms onto
/// neighbors in Castle 3/4 scans (Playroom→Tent, Meditation→Terrace).
TfliteProcessedGuess? pickGuessForCell(
  List<TfliteProcessedGuess> guesses,
  GridCell cell,
  TileSelectionCalibration calibration, {
  Map<Object, int> usedCopies = const {},
  Set<GridCell> marked = const {},
}) {
  if (cell.x == 1 && cell.y == 0) return null;

  TfliteProcessedGuess? bestCovered;
  var bestCoveredKey = -1.0;
  TfliteProcessedGuess? bestThrone;
  var bestThroneScore = -1.0;

  final claimed = marked.isEmpty
      ? <GridCell>{}
      : Set<GridCell>.from(marked);

  for (final g in guesses) {
    if (cell.x == 0 && cell.y == 0) {
      if (!TfliteHelper.isThroneRoom(g)) continue;
      if (g.score > bestThroneScore) {
        bestThroneScore = g.score;
        bestThrone = g;
      }
      continue;
    } else if (TfliteHelper.isNonTile(g) || TfliteHelper.isThroneRoom(g)) {
      continue;
    }
    final already = usedCopies[g.label] ?? 0;
    if (already >= TfliteHelper.maxCopiesForLabel(g.label)) continue;
    final cov = coverageOfCell(g, cell, calibration);
    if (cov < kMinCellCoverage) continue;
    if (claimed.isNotEmpty) {
      final best = bestCoveredMarkedCell(g, claimed, calibration);
      if (best != cell) continue;
    }
    final key = cov + g.score * 0.01;
    if (key > bestCoveredKey) {
      bestCoveredKey = key;
      bestCovered = g;
    }
  }
  if (cell.x == 0 && cell.y == 0) return bestThrone;
  return bestCovered;
}
