import 'dart:ui';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/state/tf_store.dart';
import 'package:btcc/src/tflite/castle_build_result.dart';
import 'package:btcc/src/tflite/cell_guess_info.dart';
import 'package:btcc/src/tflite/tile_guess_placement.dart';
import 'package:btcc/src/tflite/tile_selection_geom.dart';
import 'package:btcc/src/tflite/tile_selection_match.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:btcc/src/tflite/windowed_detect.dart';
import 'package:btcc/src/utils/castle_frame_crop.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/token_tile_grid.dart';
import 'package:image/image.dart' as img;

/// Builds a [GridList] from user-marked cells + ML classification.
class TileSelectionBuilder {
  TileSelectionBuilder._();

  static Future<CastleBuildResult> buildCastleWithInfo({
    required TileSelectionCalibration calibration,
    required Set<GridCell> marked,
    required TfStore store,
    void Function(int done, int total)? onProgress,
    void Function(String phase)? onPhase,
    List<TfliteProcessedGuess>? cachedGuesses,
    img.Image? cachedDecoded,
  }) async {
    if (marked.isEmpty) {
      throw StateError('No tiles marked on the grid');
    }

    await store.prepareForScoring();

    final img.Image decoded;
    if (cachedDecoded != null) {
      decoded = cachedDecoded;
    } else {
      final expectedSize = await decodeImagePixelSize(calibration.imagePath);
      decoded = await decodeOrientedImage(
        calibration.imagePath,
        expectedSize: expectedSize,
      );
    }
    if (decoded.width == 0 || decoded.height == 0) {
      throw StateError('Could not decode image for tile selection');
    }
    log('tile selection image ${decoded.width}x${decoded.height} '
        'tile=${calibration.tileWidth.toStringAsFixed(1)}x'
        '${calibration.tileHeight.toStringAsFixed(1)}');

    final List<TfliteProcessedGuess> castleGuesses;
    if (cachedGuesses != null) {
      castleGuesses = cachedGuesses;
    } else {
      onPhase?.call('Scanning castle');
      final detectRect = _castleDetectRect(calibration, decoded);
      castleGuesses = await WindowedDetect.detectCastleWindows(
        store: store,
        decoded: decoded,
        bounds: detectRect,
        tileW: calibration.tileWidth,
        tileH: calibration.tileHeight,
      );
    }

    final cal = refineCalibrationFromGuesses(calibration, castleGuesses);
    final markedCells = TileSelectionCalibration.remapMarkedCells(
      marked: marked,
      from: calibration,
      to: cal,
    );
    if (cal.throneRect != calibration.throneRect) {
      log('tile selection refined tile='
          '${cal.tileWidth.toStringAsFixed(1)}x${cal.tileHeight.toStringAsFixed(1)} '
          '(was ${calibration.tileWidth.toStringAsFixed(1)}x'
          '${calibration.tileHeight.toStringAsFixed(1)}); '
          'marked ${marked.length} → ${markedCells.length}');
    }

    final bounds = TileSelectionCalibration.gridBounds(markedCells);
    final grid = GridList<Tile>(
      bounds.width,
      TfliteHelper.createEmptyTileList(bounds.width, bounds.height),
    );
    final guessInfo = <int, CellGuessInfo>{};

    final toClassify = markedCells.where((c) => !c.isThroneOrPlaceholder).toList()
      ..sort((a, b) => a.y == b.y ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    toClassify.insert(0, const GridCell(0, 0));

    final total = toClassify.length;
    onProgress?.call(0, total);

    final assigned = assignGuessesToMarkedCells(
      guesses: castleGuesses,
      marked: markedCells,
      calibration: cal,
    );
    log('tile selection assigned ${assigned.length}/$total '
        '(${castleGuesses.length} detections)');

    onPhase?.call('Classifying tiles');
    var done = 0;
    final usedCopies = <Object, int>{};
    for (final cell in toClassify) {
      await Future<void>.delayed(Duration.zero); // yield so UI can repaint
      onProgress?.call(done, total);
      final localX = cell.x - bounds.minX;
      final localY = cell.y - bounds.minY;
      final idx = localY * bounds.width + localX;
      if (idx < 0 || idx >= grid.items.length) {
        done++;
        continue;
      }

      var guess = assigned[cell];
      var cov = guess == null
          ? 0.0
          : coverageOfCell(guess, cell, cal);
      if (guess == null || cov < kMinCellCoverage) {
        // Accept cached match at a relaxed threshold to avoid a costly
        // per-cell inference when the detection is close but slightly under.
        if (guess != null && cov >= kFallbackAcceptCoverage) {
          // Keep the cached guess — good enough to skip the fallback crop.
        } else if (_hasNearbyDetection(castleGuesses, cell, cal)) {
          final ctx = cal.scoringContextRect(
            cell,
            imageW: decoded.width,
            imageH: decoded.height,
          );
          final ctxGuesses = await _detectRegion(store, decoded, ctx);
          guess = pickGuessForCell(
                ctxGuesses,
                cell,
                cal,
                usedCopies: usedCopies,
                marked: markedCells,
              ) ??
              guess;
          if (guess != null) {
            cov = coverageOfCell(guess, cell, cal);
          }
        }
        // No nearby detections at all — cell will be unidentified; skip the
        // expensive fallback crop that would find nothing anyway.
      }
      if (cell.x != 0 &&
          guess != null &&
          cov < kMinCellCoverage) {
        guess = null;
        cov = 0;
      }

      if (cell.x == 0 && cell.y == 0) {
        grid.items[idx] = _throneFromGuess(guess);
        guessInfo[idx] = guess != null && TfliteHelper.isThroneRoom(guess)
            ? CellGuessInfo.fromGuess(score: guess.score, coverage: cov)
            : CellGuessInfo.fromGuess(score: 0.5, coverage: 0.5);
      } else if (guess != null && !TfliteHelper.isNonTile(guess)) {
        final already = usedCopies[guess.label] ?? 0;
        if (already >= TfliteHelper.maxCopiesForLabel(guess.label)) {
          grid.items[idx] = Empty();
          guessInfo[idx] = CellGuessInfo.unidentifiedCell();
        } else {
          final tile = TileGuessPlacement.tryGetTile(guess, grid.items);
          if (tile != null) {
            grid.items[idx] = tile;
            guessInfo[idx] = TileGuessPlacement.infoFromGuess(
              guess: guess,
              coverage: cov,
            );
            usedCopies[guess.label] = already + 1;
          } else {
            grid.items[idx] = Empty();
            guessInfo[idx] = CellGuessInfo.unidentifiedCell();
          }
        }
      } else if (markedCells.contains(cell)) {
        grid.items[idx] = Empty();
        guessInfo[idx] = CellGuessInfo.unidentifiedCell();
      }
      done++;
    }

    final emptyMarked = <GridCell>{};
    for (final cell in markedCells) {
      if (cell.isThroneOrPlaceholder) continue;
      final localX = cell.x - bounds.minX;
      final localY = cell.y - bounds.minY;
      final idx = localY * bounds.width + localX;
      if (idx >= 0 &&
          idx < grid.items.length &&
          grid.items[idx].isEmpty()) {
        emptyMarked.add(cell);
      }
    }
    if (emptyMarked.isNotEmpty) {
      final refill = assignGuessesToMarkedCells(
        guesses: castleGuesses,
        marked: {
          ...emptyMarked,
          const GridCell(0, 0),
          const GridCell(1, 0),
        },
        calibration: cal,
        usedCopies: usedCopies,
      );
      for (final e in refill.entries) {
        if (e.key.isThroneOrPlaceholder) continue;
        final cell = e.key;
        final guess = e.value;
        final localX = cell.x - bounds.minX;
        final localY = cell.y - bounds.minY;
        final idx = localY * bounds.width + localX;
        if (idx < 0 || idx >= grid.items.length) continue;
        if (!grid.items[idx].isEmpty()) continue;
        final already = usedCopies[guess.label] ?? 0;
        if (already >= TfliteHelper.maxCopiesForLabel(guess.label)) continue;
        final tile = TileGuessPlacement.tryGetTile(guess, grid.items);
        if (tile == null) continue;
        grid.items[idx] = tile;
        guessInfo[idx] = TileGuessPlacement.infoFromGuess(
          guess: guess,
          coverage: coverageOfCell(guess, cell, cal),
        );
        usedCopies[guess.label] = already + 1;
      }
    }

    if (markedCells.contains(const GridCell(1, 0))) {
      final phIdx = (0 - bounds.minY) * bounds.width + (1 - bounds.minX);
      if (phIdx >= 0 && phIdx < grid.items.length) {
        grid.items[phIdx] = Placeholder();
      }
    }

    onProgress?.call(total, total);

    final tokens = TfliteHelper.collectTokenTiles(castleGuesses);
    var withTokens = grid;
    var outGuesses = Map<int, CellGuessInfo>.from(guessInfo);
    if (tokens.isNotEmpty) {
      withTokens = TokenTileGrid.mergeTokenTilesIntoGrid(
        grid,
        tokens,
        getEmpty: () => Empty(),
      );
      if (withTokens.height > grid.height) {
        final remapped = <int, CellGuessInfo>{};
        for (final entry in guessInfo.entries) {
          final x = entry.key % grid.width;
          final y = entry.key ~/ grid.width;
          remapped[x + (y + 1) * withTokens.width] = entry.value;
        }
        outGuesses = remapped;
      }
    }

    log('tile selection built ${withTokens.width}x${withTokens.height} '
        '(${outGuesses.values.where((g) => g.unidentified).length} unidentified)');
    return CastleBuildResult(grid: withTokens, cellGuesses: outGuesses);
  }

  static Future<GridList<Tile>> buildCastle({
    required TileSelectionCalibration calibration,
    required Set<GridCell> marked,
    required TfStore store,
    void Function(int done, int total)? onProgress,
  }) async {
    final result = await buildCastleWithInfo(
      calibration: calibration,
      marked: marked,
      store: store,
      onProgress: onProgress,
    );
    return result.grid;
  }

  static Tile _throneFromGuess(TfliteProcessedGuess? guess) {
    if (guess != null && TfliteHelper.isThroneRoom(guess)) {
      return TfliteHelper.getCorrectTile(guess, const []);
    }
    return TileHelper().getTileByLabel(TileLabels.TRCD);
  }

  static Rect _castleDetectRect(
    TileSelectionCalibration calibration,
    img.Image decoded,
  ) {
    final b = calibration.boundsRect;
    return Rect.fromLTRB(
      b.left.clamp(0, decoded.width.toDouble()),
      b.top.clamp(0, decoded.height.toDouble()),
      b.right.clamp(0, decoded.width.toDouble()),
      b.bottom.clamp(0, decoded.height.toDouble()),
    );
  }

  /// Whether any cached detection overlaps [cell] at all — if not, a fallback
  /// crop is unlikely to find anything useful.
  static bool _hasNearbyDetection(
    List<TfliteProcessedGuess> guesses,
    GridCell cell,
    TileSelectionCalibration cal,
  ) {
    for (final g in guesses) {
      if (TfliteHelper.isNonTile(g)) continue;
      if (coverageOfCell(g, cell, cal) > 0) return true;
    }
    return false;
  }

  static Future<List<TfliteProcessedGuess>> _detectRegion(
    TfStore store,
    img.Image decoded,
    Rect rect,
  ) async {
    final left = rect.left.floor().clamp(0, decoded.width - 1);
    final top = rect.top.floor().clamp(0, decoded.height - 1);
    final width = rect.width.round().clamp(1, decoded.width - left);
    final height = rect.height.round().clamp(1, decoded.height - top);
    if (width < 8 || height < 8) return const [];
    final local = await store.runOnImageCrop(
      decoded,
      x: left,
      y: top,
      width: width,
      height: height,
    );
    return [
      for (final g in local) g.translated(left.toDouble(), top.toDouble()),
    ];
  }
}
