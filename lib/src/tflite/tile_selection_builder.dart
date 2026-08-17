import 'dart:ui';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/state/tf_store.dart';
import 'package:btcc/src/tflite/tile_selection_geom.dart';
import 'package:btcc/src/tflite/tile_selection_match.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:btcc/src/utils/castle_frame_crop.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:image/image.dart' as img;

/// Builds a [GridList] from user-marked cells + ML classification.
class TileSelectionBuilder {
  TileSelectionBuilder._();

  static Future<GridList<Tile>> buildCastle({
    required TileSelectionCalibration calibration,
    required Set<GridCell> marked,
    required TfStore store,
    void Function(int done, int total)? onProgress,
  }) async {
    if (marked.isEmpty) {
      throw StateError('No tiles marked on the grid');
    }

    await store.prepareForScoring();

    final decoded = await decodeOrientedImage(calibration.imagePath);
    if (decoded.width == 0 || decoded.height == 0) {
      throw StateError('Could not decode image for tile selection');
    }

    final bounds = TileSelectionCalibration.gridBounds(marked);
    final grid = GridList<Tile>(
      bounds.width,
      TfliteHelper.createEmptyTileList(bounds.width, bounds.height),
    );

    final toClassify = marked.where((c) => !c.isThroneOrPlaceholder).toList()
      ..sort((a, b) => a.y == b.y ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    // Classify throne first, then rooms.
    toClassify.insert(0, const GridCell(0, 0));

    final total = toClassify.length;
    onProgress?.call(0, total);

    final castleGuesses = await _detectRegion(
      store,
      decoded,
      _castleDetectRect(calibration, decoded),
    );
    final assigned = assignGuessesToMarkedCells(
      guesses: castleGuesses,
      marked: marked,
      calibration: calibration,
    );
    log('tile selection pass1 assigned ${assigned.length}/$total '
        '(${castleGuesses.length} detections)');

    var done = 0;
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
      if (guess == null) {
        final ctx = calibration.contextRect(
          cell,
          imageW: decoded.width,
          imageH: decoded.height,
        );
        final ctxGuesses = await _detectRegion(store, decoded, ctx);
        guess = pickGuessForCell(ctxGuesses, cell, calibration);
        log('tile selection fallback $cell '
            '${guess?.label ?? "none"} (${ctxGuesses.length} in context)');
      }

      if (cell.x == 0 && cell.y == 0) {
        grid.items[idx] = _throneFromGuess(guess);
      } else if (guess != null && !TfliteHelper.isNonTile(guess)) {
        try {
          grid.items[idx] = TfliteHelper.getCorrectTile(guess, grid.items);
        } catch (ex) {
          log('tile selection classify failed at $cell: $ex');
        }
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
    final placed = grid.items.where((t) => !t.isEmpty()).length;
    log('tile selection built ${bounds.width}x${bounds.height} grid '
        '($placed placed)');
    return grid;
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
    final padX = calibration.tileWidth * 0.5;
    final padY = calibration.tileHeight * 0.5;
    final b = calibration.boundsRect;
    return Rect.fromLTRB(
      (b.left - padX).clamp(0, decoded.width.toDouble()),
      (b.top - padY).clamp(0, decoded.height.toDouble()),
      (b.right + padX).clamp(0, decoded.width.toDouble()),
      (b.bottom + padY).clamp(0, decoded.height.toDouble()),
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
