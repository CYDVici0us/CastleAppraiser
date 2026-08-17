import 'dart:math' as math;

import 'package:btcc/src/tflite/castle_typical_extents.dart';

/// Axis-aligned crop for a zoom/pan refine pass.
class ContentBandCrop {
  final int x;
  final int y;
  final int width;
  final int height;
  final String tag;

  const ContentBandCrop({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.tag = 'crop',
  });

  @override
  String toString() => '$tag ${width}x$height@($x,$y)';
}

/// Planned refine crops after a full-frame pass.
class ZoomPanPlan {
  final List<ContentBandCrop> crops;
  final String reason;

  const ZoomPanPlan({required this.crops, required this.reason});

  static const empty = ZoomPanPlan(crops: [], reason: 'none');
}

/// Adaptive zoom+pan for wing / tower recall:
///
/// * **Portrait** → left/right strips. Wings often stack **4+ tiles** above and
///   below ground level, so we use tall strips (or upper+lower pans per side)
///   instead of a mid-height square that clipped vertical stacks.
/// * **Landscape** → top/bottom strips with full width when needed.
///
/// Returns at most [maxCrops] crops (default 4).
ZoomPanPlan planZoomPanCrops({
  required int imageW,
  required int imageH,
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
  required double avgTileW,
  required double avgTileH,
  int maxCrops = 4,
}) {
  if (maxCrops < 1) return ZoomPanPlan.empty;
  if (imageW < 1 || imageH < 1) return ZoomPanPlan.empty;
  if (!(avgTileW > 0) || !(avgTileH > 0)) return ZoomPanPlan.empty;
  if (!(maxX > minX) || !(maxY > minY)) return ZoomPanPlan.empty;

  final portrait = imageH >= imageW * 1.15;
  final landscape = imageW >= imageH * 1.15;
  if (!portrait && !landscape) {
    return const ZoomPanPlan(crops: [], reason: 'near-square');
  }

  final mx = math.max(avgTileW * 2.0, imageW * 0.04);
  final my = math.max(avgTileH * 2.0, imageH * 0.04);

  final expanded = CastleTypicalExtents.expandDetectionBounds(
    minX: minX,
    maxX: maxX,
    minY: minY,
    maxY: maxY,
    avgTileW: avgTileW,
    avgTileH: avgTileH,
    imageW: imageW,
    imageH: imageH,
  );
  minX = expanded.minX;
  maxX = expanded.maxX;
  minY = expanded.minY;
  maxY = expanded.maxY;

  if (portrait) {
    if (maxCrops >= 2) {
      final pans = _portraitWingZooms(
        imageW: imageW,
        imageH: imageH,
        avgTileW: avgTileW,
        avgTileH: avgTileH,
        maxCrops: maxCrops,
      );
      if (pans.isNotEmpty) {
        return ZoomPanPlan(
          crops: pans,
          reason: pans.length > 2 ? 'portrait-lr-quad' : 'portrait-lr',
        );
      }
    }
    final band = _portraitBand(
      imageW: imageW,
      imageH: imageH,
      minY: minY,
      maxY: maxY,
      my: my,
    );
    if (band != null) {
      return ZoomPanPlan(crops: [band], reason: 'portrait-band');
    }
    return const ZoomPanPlan(crops: [], reason: 'portrait-skip');
  }

  if (maxCrops >= 2) {
    final pans = _landscapeWingZooms(
      imageW: imageW,
      imageH: imageH,
      avgTileW: avgTileW,
      avgTileH: avgTileH,
      maxCrops: maxCrops,
    );
    if (pans.isNotEmpty) {
      return ZoomPanPlan(
        crops: pans,
        reason: pans.length > 2 ? 'landscape-tb-quad' : 'landscape-tb',
      );
    }
  }
  final band = _landscapeBand(
    imageW: imageW,
    imageH: imageH,
    minX: minX,
    maxX: maxX,
    mx: mx,
  );
  if (band != null) {
    return ZoomPanPlan(crops: [band], reason: 'landscape-band');
  }
  return const ZoomPanPlan(crops: [], reason: 'landscape-skip');
}

/// Legacy single-band helper (tests / callers that only want the band).
ContentBandCrop? computeContentBandCrop({
  required int imageW,
  required int imageH,
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
  required double avgTileW,
  required double avgTileH,
}) {
  final portrait = imageH >= imageW * 1.15;
  if (portrait) {
    return _portraitBand(
      imageW: imageW,
      imageH: imageH,
      minY: minY,
      maxY: maxY,
      my: math.max(avgTileH * 2.0, imageH * 0.04),
    );
  }
  if (imageW >= imageH * 1.15) {
    return _landscapeBand(
      imageW: imageW,
      imageH: imageH,
      minX: minX,
      maxX: maxX,
      mx: math.max(avgTileW * 2.0, imageW * 0.04),
    );
  }
  return null;
}

ContentBandCrop? _portraitBand({
  required int imageW,
  required int imageH,
  required double minY,
  required double maxY,
  required double my,
}) {
  final targetH = math.max(imageW, (imageW * 1.1).round());
  final midY = (minY + maxY) / 2.0;
  var y0 = (midY - targetH / 2.0).floor();
  var y1 = y0 + targetH;
  if (y0 < 0) {
    y1 -= y0;
    y0 = 0;
  }
  if (y1 > imageH) {
    y0 -= (y1 - imageH);
    y1 = imageH;
    if (y0 < 0) y0 = 0;
  }
  final cropH = y1 - y0;
  if (cropH < 1 || cropH >= imageH * 0.92) return null;
  final fullAspect = imageH / imageW;
  final cropAspect = math.max(imageW, cropH) / math.min(imageW, cropH);
  if (cropAspect >= fullAspect * 0.92) return null;
  return ContentBandCrop(
    x: 0,
    y: y0,
    width: imageW,
    height: cropH,
    tag: 'band',
  );
}

ContentBandCrop? _landscapeBand({
  required int imageW,
  required int imageH,
  required double minX,
  required double maxX,
  required double mx,
}) {
  final targetW = math.max(imageH, (imageH * 1.1).round());
  final midX = (minX + maxX) / 2.0;
  var x0 = (midX - targetW / 2.0).floor();
  var x1 = x0 + targetW;
  if (x0 < 0) {
    x1 -= x0;
    x0 = 0;
  }
  if (x1 > imageW) {
    x0 -= (x1 - imageW);
    x1 = imageW;
    if (x0 < 0) x0 = 0;
  }
  final cropW = x1 - x0;
  if (cropW < 1 || cropW >= imageW * 0.92) return null;
  final fullAspect = imageW / imageH;
  final cropAspect = math.max(cropW, imageH) / math.min(cropW, imageH);
  if (cropAspect >= fullAspect * 0.92) return null;
  return ContentBandCrop(
    x: x0,
    y: 0,
    width: cropW,
    height: imageH,
    tag: 'band',
  );
}

/// Portrait wings: full-height L/R when the frame is moderate; for very tall
/// images, upper+lower pans per side so 4+ tile stacks aren't mid-clipped.
List<ContentBandCrop> _portraitWingZooms({
  required int imageW,
  required int imageH,
  required double avgTileW,
  required double avgTileH,
  required int maxCrops,
}) {
  final stripW = CastleTypicalExtents.wingStripWidthPx(
    imageW: imageW,
    avgTileW: avgTileW,
  );
  if (stripW >= imageW * 0.95) return const [];

  final needsVerticalSplit = maxCrops >= 4 &&
      CastleTypicalExtents.needsVerticalWingSplit(
        imageH: imageH,
        imageW: imageW,
        avgTileH: avgTileH,
      );
  if (needsVerticalSplit) {
    final bandH = CastleTypicalExtents.wingBandHeightPx(
      imageH: imageH,
      avgTileH: avgTileH,
    );
    final yTop = 0;
    final yBot = math.max(0, imageH - bandH);
    if (yBot <= yTop + bandH * 0.15) {
      // Overlap almost full height — collapse to 2 full-height strips.
      return _portraitFullHeightSides(imageW, imageH, stripW);
    }
    return [
      ContentBandCrop(
        x: 0,
        y: yTop,
        width: stripW,
        height: bandH,
        tag: 'zoom-left-top',
      ),
      ContentBandCrop(
        x: 0,
        y: yBot,
        width: stripW,
        height: bandH,
        tag: 'zoom-left-bot',
      ),
      ContentBandCrop(
        x: imageW - stripW,
        y: yTop,
        width: stripW,
        height: bandH,
        tag: 'zoom-right-top',
      ),
      ContentBandCrop(
        x: imageW - stripW,
        y: yBot,
        width: stripW,
        height: bandH,
        tag: 'zoom-right-bot',
      ),
    ].take(maxCrops).toList();
  }

  return _portraitFullHeightSides(imageW, imageH, stripW);
}

List<ContentBandCrop> _portraitFullHeightSides(
  int imageW,
  int imageH,
  int stripW,
) {
  return [
    ContentBandCrop(
      x: 0,
      y: 0,
      width: stripW,
      height: imageH,
      tag: 'zoom-left',
    ),
    ContentBandCrop(
      x: imageW - stripW,
      y: 0,
      width: stripW,
      height: imageH,
      tag: 'zoom-right',
    ),
  ];
}

/// Landscape: full-width T/B, or left/right split on very wide frames.
List<ContentBandCrop> _landscapeWingZooms({
  required int imageW,
  required int imageH,
  required double avgTileW,
  required double avgTileH,
  required int maxCrops,
}) {
  final stripH = CastleTypicalExtents.wingStripHeightPx(
    imageH: imageH,
    avgTileH: avgTileH,
  );
  if (stripH >= imageH * 0.95) return const [];

  final needsHorizontalSplit = maxCrops >= 4 &&
      imageW > imageH * 1.2 &&
      imageW >= avgTileW * CastleTypicalExtents.baseWidthWide * 0.85;
  if (needsHorizontalSplit) {
    final bandW = math
        .max(
          stripH,
          math.max((avgTileW * 6).round(), (imageW * 0.58).round()),
        )
        .clamp(1, imageW)
        .toInt();
    const xLeft = 0;
    final xRight = math.max(0, imageW - bandW);
    if (xRight <= xLeft + bandW * 0.15) {
      return _landscapeFullWidthEnds(imageW, imageH, stripH);
    }
    return [
      ContentBandCrop(
        x: xLeft,
        y: 0,
        width: bandW,
        height: stripH,
        tag: 'zoom-top-left',
      ),
      ContentBandCrop(
        x: xRight,
        y: 0,
        width: bandW,
        height: stripH,
        tag: 'zoom-top-right',
      ),
      ContentBandCrop(
        x: xLeft,
        y: imageH - stripH,
        width: bandW,
        height: stripH,
        tag: 'zoom-bot-left',
      ),
      ContentBandCrop(
        x: xRight,
        y: imageH - stripH,
        width: bandW,
        height: stripH,
        tag: 'zoom-bot-right',
      ),
    ].take(maxCrops).toList();
  }

  return _landscapeFullWidthEnds(imageW, imageH, stripH);
}

List<ContentBandCrop> _landscapeFullWidthEnds(
  int imageW,
  int imageH,
  int stripH,
) {
  return [
    ContentBandCrop(
      x: 0,
      y: 0,
      width: imageW,
      height: stripH,
      tag: 'zoom-top',
    ),
    ContentBandCrop(
      x: 0,
      y: imageH - stripH,
      width: imageW,
      height: stripH,
      tag: 'zoom-bottom',
    ),
  ];
}
