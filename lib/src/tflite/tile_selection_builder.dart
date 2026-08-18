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
  }) async {
    if (marked.isEmpty) {
      throw StateError('No tiles marked on the grid');
    }

    await store.prepareForScoring();

    final expectedSize = await decodeImagePixelSize(calibration.imagePath);
    final decoded = await decodeOrientedImage(
      calibration.imagePath,
      expectedSize: expectedSize,
    );
    if (decoded.width == 0 || decoded.height == 0) {
      throw StateError('Could not decode image for tile selection');
    }
    log('tile selection image ${decoded.width}x${decoded.height} '
        'tile=${calibration.tileWidth.toStringAsFixed(1)}x'
        '${calibration.tileHeight.toStringAsFixed(1)}');

    final bounds = TileSelectionCalibration.gridBounds(marked);
    final grid = GridList<Tile>(
      bounds.width,
      TfliteHelper.createEmptyTileList(bounds.width, bounds.height),
    );
    final guessInfo = <int, CellGuessInfo>{};

    final toClassify = marked.where((c) => !c.isThroneOrPlaceholder).toList()
      ..sort((a, b) => a.y == b.y ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    toClassify.insert(0, const GridCell(0, 0));

    final total = toClassify.length;
    onProgress?.call(0, total);

    final detectRect = _castleDetectRect(calibration, decoded);
    final castleGuesses = await WindowedDetect.detectCastleWindows(
      store: store,
      decoded: decoded,
      bounds: detectRect,
      tileW: calibration.tileWidth,
      tileH: calibration.tileHeight,
    );

    final assigned = assignGuessesToMarkedCells(
      guesses: castleGuesses,
      marked: marked,
      calibration: calibration,
    );
    log('tile selection assigned ${assigned.length}/$total '
        '(${castleGuesses.length} detections)');

    var done = 0;
    final usedCopies = <Object, int>{};
    for (final cell in toClassify) {
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
          : coverageOfCell(guess, cell, calibration);
      if (guess == null || cov < kMinCellCoverage) {
        final ctx = calibration.scoringContextRect(
          cell,
          imageW: decoded.width,
          imageH: decoded.height,
        );
        final ctxGuesses = await _detectRegion(store, decoded, ctx);
        guess = pickGuessForCell(
              ctxGuesses,
              cell,
              calibration,
              usedCopies: usedCopies,
            ) ??
            guess;
        if (guess != null) {
          cov = coverageOfCell(guess, cell, calibration);
        }
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
      } else if (marked.contains(cell)) {
        grid.items[idx] = Empty();
        guessInfo[idx] = CellGuessInfo.unidentifiedCell();
      }
      done++;
    }

    if (marked.contains(const GridCell(1, 0))) {
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
