import 'dart:math' as math;
import 'dart:ui';

import 'package:btcc/src/state/tf_store.dart';
import 'package:btcc/src/tflite/castle_typical_extents.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:btcc/src/tflite/tile_selection_geom.dart';
import 'package:image/image.dart' as img;

/// Overlapping ~8×8-tile windows at model training scale.
class WindowedDetect {
  WindowedDetect._();

  static Future<List<TfliteProcessedGuess>> detectCastleWindows({
    required TfStore store,
    required img.Image decoded,
    required Rect bounds,
    required double tileW,
    required double tileH,
    int strideTiles = 4,
  }) async {
    final pitch = math.max(tileW, tileH);
    final windowSide = pitch * CastleTypicalExtents.baseWidthTypical;
    if (windowSide <= 0 || bounds.width < 8 || bounds.height < 8) {
      return _detectRegion(store, decoded, bounds);
    }

    final stride = pitch * strideTiles;
    final merged = <TfliteProcessedGuess>[];
    for (var top = bounds.top;
        top < bounds.bottom - 8;
        top += stride) {
      for (var left = bounds.left;
          left < bounds.right - 8;
          left += stride) {
        final win = Rect.fromLTWH(
          left,
          top,
          math.min(windowSide, bounds.right - left),
          math.min(windowSide, bounds.bottom - top),
        );
        final local = await _detectRegion(store, decoded, win);
        merged.addAll(local);
      }
    }

    if (merged.isEmpty) {
      return _detectRegion(store, decoded, bounds);
    }
    return TfliteHelper.classAwareNms(merged);
  }

  /// Pre-mark grid cells from detections snapped to throne calibration.
  static Set<GridCell> seedMarkedCells({
    required List<TfliteProcessedGuess> guesses,
    required TileSelectionCalibration calibration,
    required Set<GridCell> alwaysMarked,
  }) {
    final marked = Set<GridCell>.from(alwaysMarked);
    for (final g in guesses) {
      if (TfliteHelper.isNonTile(g)) continue;
      if (TfliteHelper.isThroneRoom(g)) continue;
      final cx = (g.xMin + g.xMax) / 2;
      final cy = (g.yMin + g.yMax) / 2;
      final cell = calibration.cellAtImagePoint(
        Offset(cx, cy),
        requireInBounds: true,
      );
      if (cell != null && !cell.isThroneOrPlaceholder) {
        marked.add(cell);
      }
    }
    return marked;
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
