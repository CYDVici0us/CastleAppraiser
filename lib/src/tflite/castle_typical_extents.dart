import 'dart:math' as math;

/// Typical castle footprint in **tile counts** (Between Two Castles table photos).
///
/// Used to size the user framing box and to expand refine crops when pass-1
/// detections only cover the center tower (wings/basement still missed).
class CastleTypicalExtents {
  CastleTypicalExtents._();

  /// Tower height above ground floor (common).
  static const int tilesAboveGround = 5;

  /// Basement depth (often 3–5 below ground).
  static const int tilesBelowGroundTypical = 4;
  static const int tilesBelowGroundMax = 5;

  /// Base width including throne (2-wide) and wings (often 5–10+).
  static const int baseWidthTypical = 8;
  static const int baseWidthWide = 10;

  /// Ground row + tower + typical basement.
  static const int verticalSpanTiles =
      1 + tilesAboveGround + tilesBelowGroundTypical; // 10

  static const int verticalSpanMaxTiles =
      1 + tilesAboveGround + tilesBelowGroundMax; // 11

  /// Framing box aspects (width ÷ height) tuned to those spans.
  static const double portraitFrameAspect =
      baseWidthTypical / verticalSpanMaxTiles; // ~8/11 tall castle
  static const double landscapeFrameAspect =
      baseWidthWide / (verticalSpanTiles - 2); // ~10/8 wide castle

  /// Extra crop columns so bonus cards and royal attendants beside the castle
  /// (or on the throne) are not clipped when the user frames rooms only.
  static const double tokenMarginTilesX = 2.0;

  /// Extra crop rows for tokens sitting on/just above the throne row.
  static const double tokenMarginTilesY = 1.25;

  /// Expand a pass-1 detection AABB so refine pans cover basement + tower
  /// even when only the center stack was detected.
  static ({
    double minX,
    double maxX,
    double minY,
    double maxY,
  }) expandDetectionBounds({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required double avgTileW,
    required double avgTileH,
    required int imageW,
    required int imageH,
  }) {
    if (!(avgTileW > 0) || !(avgTileH > 0)) {
      return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
    }

    final targetH = avgTileH * verticalSpanMaxTiles;
    final targetW = avgTileW * baseWidthWide;

    var cx = (minX + maxX) / 2;
    var cy = (minY + maxY) / 2;
    var spanX = maxX - minX;
    var spanY = maxY - minY;

    if (spanY < targetH * 0.88) {
      minY = cy - targetH / 2;
      maxY = cy + targetH / 2;
      spanY = targetH;
    }
    if (spanX < targetW * 0.88) {
      minX = cx - targetW / 2;
      maxX = cx + targetW / 2;
      spanX = targetW;
    }

    // Small margin beyond tile-count box.
    final mx = avgTileW * 0.75;
    final my = avgTileH * 0.75;
    minX = (minX - mx).clamp(0.0, imageW.toDouble());
    maxX = (maxX + mx).clamp(0.0, imageW.toDouble());
    minY = (minY - my).clamp(0.0, imageH.toDouble());
    maxY = (maxY + my).clamp(0.0, imageH.toDouble());

    if (maxX <= minX || maxY <= minY) {
      return (
        minX: 0.0,
        maxX: imageW.toDouble(),
        minY: 0.0,
        maxY: imageH.toDouble(),
      );
    }
    return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  /// Side wing strip width (~4 tile columns), capped so L/R strips stay on
  /// the edges and do not swallow the center tower (72% was ~full frame).
  static int wingStripWidthPx({
    required int imageW,
    required double avgTileW,
  }) {
    final byTiles = (avgTileW * 4).round();
    final cap = (imageW * 0.38).round();
    return math.max(64, math.min(byTiles, cap));
  }

  /// Top/bottom strip height in landscape (~4 tile rows), edge-capped.
  static int wingStripHeightPx({
    required int imageH,
    required double avgTileH,
  }) {
    final byTiles = (avgTileH * 4).round();
    final cap = (imageH * 0.38).round();
    return math.max(64, math.min(byTiles, cap));
  }

  /// Height of each upper/lower wing pan (~6 tile rows, overlapping).
  static int wingBandHeightPx({
    required int imageH,
    required double avgTileH,
  }) {
    final byTiles = (avgTileH * 6).round();
    final byFraction = (imageH * 0.58).round();
    return math.max(byTiles, byFraction).clamp(1, imageH);
  }

  /// Use quad wing pans when the frame is tall enough for ~10 tile rows.
  static bool needsVerticalWingSplit({
    required int imageH,
    required int imageW,
    required double avgTileH,
  }) {
    if (avgTileH > 0 && imageH >= avgTileH * verticalSpanTiles * 0.85) {
      return true;
    }
    return imageH > imageW * 1.2;
  }
}
