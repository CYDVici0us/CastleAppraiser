import 'dart:math' as math;
import 'dart:ui';

import 'package:btcc/src/tflite/castle_typical_extents.dart';
import 'package:btcc/src/tflite/throne_anchored_lattice.dart';

/// Integer grid coordinate relative to the throne anchor (left cell of 2-wide
/// throne at ground row = (0, 0); placeholder at (1, 0)).
class GridCell {
  final int x;
  final int y;

  const GridCell(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  /// Left cell of the 2-wide throne, or the unused east placeholder.
  bool get isThroneOrPlaceholder =>
      (x == 0 && y == 0) || (x == 1 && y == 0);

  @override
  String toString() => '($x,$y)';
}

/// Room tiles the user tapped. Throne and placeholder are always marked
/// and are not counted toward [expectedRoomTileCount].
int countMarkedRoomTiles(Iterable<GridCell> marked) =>
    marked.where((c) => !c.isThroneOrPlaceholder).length;

/// User calibration from the tile-selection wizard.
class TileSelectionCalibration {
  final String imagePath;
  final Rect throneRect;
  final Rect boundsRect;

  const TileSelectionCalibration({
    required this.imagePath,
    required this.throneRect,
    required this.boundsRect,
  });

  double get tileWidth => throneRect.width / 2;
  double get tileHeight => tileWidth;

  /// Image-space rect for a single grid cell.
  Rect cellRect(GridCell cell) {
    return Rect.fromLTWH(
      throneRect.left + cell.x * tileWidth,
      throneRect.top + cell.y * tileHeight,
      tileWidth,
      tileHeight,
    );
  }

  Rect throneStrip() => Rect.fromLTWH(
        throneRect.left,
        throneRect.top,
        tileWidth * 2,
        tileHeight,
      );

  Offset cellCenter(GridCell cell) {
    if (cell.x == 0 && cell.y == 0) return throneStrip().center;
    return cellRect(cell).center;
  }

  /// Crop sent to the classifier (throne uses full 2-wide strip).
  Rect classifyRect(GridCell cell) {
    final base = (cell.x == 0 && cell.y == 0) ? throneStrip() : cellRect(cell);
    final pad = math.min(base.width, base.height) * 0.08;
    return base.inflate(pad);
  }

  /// Neighborhood around [cell] so the scoring model sees tiles at castle
  /// scale (a single-tile crop fills 1664px and scores ~0).
  Rect contextRect(
    GridCell cell, {
    required int imageW,
    required int imageH,
    int padTiles = 3,
  }) {
    final core = (cell.x == 0 && cell.y == 0) ? throneStrip() : cellRect(cell);
    final r = Rect.fromLTRB(
      core.left - padTiles * tileWidth,
      core.top - padTiles * tileHeight,
      core.right + padTiles * tileWidth,
      core.bottom + padTiles * tileHeight,
    );
    return _clampToImage(r, imageW, imageH);
  }

  /// ~8×8 tile window centered on [cell], matching scoring-model training scale
  /// (1664px ≈ 8 typical tiles across).
  Rect scoringContextRect(
    GridCell cell, {
    required int imageW,
    required int imageH,
  }) {
    final pitch = math.max(tileWidth, tileHeight);
    final side = pitch * CastleTypicalExtents.baseWidthTypical;
    final c = cellCenter(cell);
    return _clampToImage(
      Rect.fromCenter(center: c, width: side, height: side),
      imageW,
      imageH,
    );
  }

  static Rect _clampToImage(Rect r, int imageW, int imageH) {
    return Rect.fromLTRB(
      r.left.clamp(0, imageW.toDouble()),
      r.top.clamp(0, imageH.toDouble()),
      r.right.clamp(0, imageW.toDouble()),
      r.bottom.clamp(0, imageH.toDouble()),
    );
  }

  /// Rebuild the 2-wide throne box from a refined lattice (same bounds).
  TileSelectionCalibration refinePitch(
    Iterable<(int gx, int gy, double cx, double cy)> samples,
  ) {
    final refined = ThroneAnchoredLattice(
      originX: throneRect.left,
      originY: throneRect.top,
      tileW: tileWidth,
      tileH: tileHeight,
    ).refinePitch(samples: samples);
    return TileSelectionCalibration(
      imagePath: imagePath,
      throneRect: Rect.fromLTWH(
        refined.originX,
        refined.originY,
        refined.tileW * 2,
        refined.tileH,
      ),
      boundsRect: boundsRect,
    );
  }

  GridCell? cellAtImagePoint(
    Offset imagePoint, {
    bool requireInBounds = true,
  }) {
    if (requireInBounds && !boundsRect.contains(imagePoint)) return null;
    final gx = ((imagePoint.dx - throneRect.left) / tileWidth).floor();
    final gy = ((imagePoint.dy - throneRect.top) / tileHeight).floor();
    if (gx < -20 || gy < -20 || gx > 40 || gy > 40) return null;
    if (requireInBounds) {
      final r = Rect.fromLTWH(
        throneRect.left + gx * tileWidth,
        throneRect.top + gy * tileHeight,
        tileWidth,
        tileHeight,
      );
      if (!boundsRect.overlaps(r.inflate(2))) return null;
    }
    return GridCell(gx, gy);
  }

  /// Grid cells whose rects intersect [boundsRect].
  Iterable<GridCell> cellsInBounds() sync* {
    final minGx =
        ((boundsRect.left - throneRect.left) / tileWidth).floor() - 1;
    final maxGx =
        ((boundsRect.right - throneRect.left) / tileWidth).ceil() + 1;
    final minGy =
        ((boundsRect.top - throneRect.top) / tileHeight).floor() - 1;
    final maxGy =
        ((boundsRect.bottom - throneRect.top) / tileHeight).ceil() + 1;
    for (var gy = minGy; gy <= maxGy; gy++) {
      for (var gx = minGx; gx <= maxGx; gx++) {
        final r = Rect.fromLTWH(
          throneRect.left + gx * tileWidth,
          throneRect.top + gy * tileHeight,
          tileWidth,
          tileHeight,
        );
        if (boundsRect.overlaps(r)) {
          yield GridCell(gx, gy);
        }
      }
    }
  }

  /// Map occupancy taps from [from] onto [to] by each cell's image-space center.
  static Set<GridCell> remapMarkedCells({
    required Set<GridCell> marked,
    required TileSelectionCalibration from,
    required TileSelectionCalibration to,
  }) {
    final out = <GridCell>{
      const GridCell(0, 0),
      const GridCell(1, 0),
    };
    for (final cell in marked) {
      if (cell.isThroneOrPlaceholder) continue;
      final mapped = to.cellAtImagePoint(
        from.cellCenter(cell),
        requireInBounds: true,
      );
      if (mapped == null || mapped.isThroneOrPlaceholder) continue;
      out.add(mapped);
    }
    return out;
  }

  /// Bounding box of [marked] in grid coordinates → grid width/height.
  static ({int minX, int minY, int width, int height}) gridBounds(
    Set<GridCell> marked,
  ) {
    var minX = marked.first.x;
    var maxX = marked.first.x;
    var minY = marked.first.y;
    var maxY = marked.first.y;
    for (final c in marked) {
      minX = math.min(minX, c.x);
      maxX = math.max(maxX, c.x);
      minY = math.min(minY, c.y);
      maxY = math.max(maxY, c.y);
    }
    return (
      minX: minX,
      minY: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
    );
  }
}

/// Frame aspects for the tile-selection wizard steps.
class TileSelectionFrameAspect {
  TileSelectionFrameAspect._();

  /// Throne room is 2 tiles wide × 1 tall.
  static const double throne = 2.0;

  static double castleBounds({required bool portrait}) => portrait
      ? CastleTypicalExtents.portraitFrameAspect
      : CastleTypicalExtents.landscapeFrameAspect;
}
