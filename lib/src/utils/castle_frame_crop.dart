import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:btcc/src/tflite/castle_typical_extents.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Geometry helpers for the castle framing step.
class CastleFrameGeom {
  /// Centered frame with custom width÷height aspect.
  static Rect frameRectAspect(
    Size viewport,
    double aspect, {
    double maxHeightFraction = 0.72,
  }) {
    final maxW = viewport.width * 0.9;
    final maxH = viewport.height * maxHeightFraction;
    double w;
    double h;
    if (maxW / maxH > aspect) {
      h = maxH;
      w = h * aspect;
    } else {
      w = maxW;
      h = w / aspect;
    }
    final left = (viewport.width - w) / 2;
    final top = (viewport.height - h) / 2;
    return Rect.fromLTWH(left, top, w, h);
  }

  /// Centered frame inside [viewport].
  ///
  /// Portrait ≈ 8×11 tile slots (tower + basement). Landscape ≈ 10×8 wide base.
  static Rect frameRect(Size viewport, {required bool portrait}) {
    final aspect = portrait
        ? CastleTypicalExtents.portraitFrameAspect
        : CastleTypicalExtents.landscapeFrameAspect;
    return frameRectAspect(viewport, aspect);
  }

  /// Layout size for [InteractiveViewer] — caps huge photos so pan/zoom bounds
  /// stay sane (full [imageSize] is still used when writing the crop).
  static Size displayLayoutSize(Size imageSize, Size viewport) {
    final cap = math.max(viewport.width, viewport.height) * 3;
    final longest = math.max(imageSize.width, imageSize.height);
    if (longest <= cap) return imageSize;
    final s = cap / longest;
    return Size(imageSize.width * s, imageSize.height * s);
  }

  static double layoutToImageScale(Size imageSize, Size layoutSize) {
    assert(layoutSize.width > 0);
    return imageSize.width / layoutSize.width;
  }

  /// Map a viewport point through the inverse of [transform] into layout
  /// coordinates (the [InteractiveViewer] child space).
  ///
  /// Prefer [viewportToLayoutFromController] when a [TransformationController]
  /// is available — it uses the same [TransformationController.toScene] path
  /// as [InteractiveViewer] gestures.
  static Offset viewportToLayout(Offset viewportPoint, Matrix4 transform) {
    final inv = Matrix4.inverted(transform);
    return MatrixUtils.transformPoint(inv, viewportPoint);
  }

  /// Viewport → layout via [TransformationController.toScene].
  static Offset viewportToLayoutFromController(
    Offset viewportPoint,
    TransformationController controller,
  ) {
    return controller.toScene(viewportPoint);
  }

  /// Layout coords → full-resolution image pixels.
  static Offset layoutToImage(
    Offset layoutPoint, {
    required Size imageSize,
    required Size layoutSize,
  }) {
    final s = layoutToImageScale(imageSize, layoutSize);
    return Offset(layoutPoint.dx * s, layoutPoint.dy * s);
  }

  /// Map a viewport point to full-resolution image pixels.
  static Offset viewportToImage(
    Offset viewportPoint,
    Matrix4 transform, {
    required Size imageSize,
    required Size layoutSize,
  }) {
    return layoutToImage(
      viewportToLayout(viewportPoint, transform),
      imageSize: imageSize,
      layoutSize: layoutSize,
    );
  }

  /// Viewport → image pixels using [TransformationController.toScene].
  static Offset viewportToImageFromController(
    Offset viewportPoint,
    TransformationController controller, {
    required Size imageSize,
    required Size layoutSize,
  }) {
    return layoutToImage(
      viewportToLayoutFromController(viewportPoint, controller),
      imageSize: imageSize,
      layoutSize: layoutSize,
    );
  }

  /// Layout → viewport using the same forward transform as the grid overlay.
  static Offset layoutToViewport(Offset layoutPoint, Matrix4 transform) {
    return MatrixUtils.transformPoint(transform, layoutPoint);
  }

  /// Image-space axis-aligned crop covering [frame] under [transform], clamped
  /// to the bitmap and slightly inflated so edge tiles are not clipped.
  ///
  /// When [forThroneCalibration] is true, only a small symmetric margin is
  /// applied and the result is forced to 2:1 (two square tiles wide × one tall)
  /// so grid cells stay square on the mark step.
  static Rect imageCropRect({
    required Rect frame,
    required Matrix4 transform,
    required int imageWidth,
    required int imageHeight,
    required Size layoutSize,
    TransformationController? controller,
    bool forThroneCalibration = false,
  }) {
    final scale = layoutToImageScale(
      Size(imageWidth.toDouble(), imageHeight.toDouble()),
      layoutSize,
    );
    Offset toLayout(Offset viewportPoint) => controller != null
        ? viewportToLayoutFromController(viewportPoint, controller)
        : viewportToLayout(viewportPoint, transform);
    final corners = <Offset>[
      toLayout(frame.topLeft),
      toLayout(frame.topRight),
      toLayout(frame.bottomLeft),
      toLayout(frame.bottomRight),
    ];
    var minX = corners.map((o) => o.dx * scale).reduce(math.min);
    var maxX = corners.map((o) => o.dx * scale).reduce(math.max);
    var minY = corners.map((o) => o.dy * scale).reduce(math.min);
    var maxY = corners.map((o) => o.dy * scale).reduce(math.max);

    final spanX = (maxX - minX).abs();
    final spanY = (maxY - minY).abs();
    final edgePad = math.max(4.0, spanX * 0.03);
    if (forThroneCalibration) {
      minX -= edgePad;
      maxX += edgePad;
      minY -= edgePad;
      maxY += edgePad;
    } else {
      // Estimate tile size from the framed castle so bonus cards / attendants
      // sitting beside the throne are still in the crop.
      final tileW = spanX / CastleTypicalExtents.baseWidthTypical;
      final tileH = spanY / CastleTypicalExtents.verticalSpanMaxTiles;
      final padX = math.max(
        edgePad,
        tileW * CastleTypicalExtents.tokenMarginTilesX,
      );
      final padY = math.max(
        edgePad,
        tileH * CastleTypicalExtents.tokenMarginTilesY,
      );
      minX -= padX;
      maxX += padX;
      minY -= padY;
      maxY += padY;
    }

    minX = minX.clamp(0.0, imageWidth.toDouble());
    maxX = maxX.clamp(0.0, imageWidth.toDouble());
    minY = minY.clamp(0.0, imageHeight.toDouble());
    maxY = maxY.clamp(0.0, imageHeight.toDouble());

    if (maxX - minX < 8 || maxY - minY < 8) {
      return Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble());
    }
    var crop = Rect.fromLTRB(minX, minY, maxX, maxY);
    if (forThroneCalibration) {
      crop = enforceThroneAspect(
        crop,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
    }
    return crop;
  }

  /// Force [rect] to 2:1 width:height (throne strip) while staying on-image.
  static Rect enforceThroneAspect(
    Rect rect, {
    required int imageWidth,
    required int imageHeight,
  }) {
    final h = rect.height;
    if (h <= 0) return rect;
    final w = h * 2;
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    var left = cx - w / 2;
    var right = cx + w / 2;
    var top = cy - h / 2;
    var bottom = cy + h / 2;

    if (left < 0) {
      right -= left;
      left = 0;
    }
    if (right > imageWidth) {
      left -= right - imageWidth;
      right = imageWidth.toDouble();
    }
    if (top < 0) {
      bottom -= top;
      top = 0;
    }
    if (bottom > imageHeight) {
      top -= bottom - imageHeight;
      bottom = imageHeight.toDouble();
    }

    left = left.clamp(0.0, imageWidth.toDouble());
    right = right.clamp(0.0, imageWidth.toDouble());
    top = top.clamp(0.0, imageHeight.toDouble());
    bottom = bottom.clamp(0.0, imageHeight.toDouble());
    if (right - left < 8 || bottom - top < 8) {
      return rect;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Initial transform so the image covers [frame] (cover fit), centered.
  /// [layoutSize] is the [InteractiveViewer] child size (may be downscaled).
  static Matrix4 coverFrame({
    required Rect frame,
    required Size layoutSize,
  }) {
    final scale = math.max(
          frame.width / layoutSize.width,
          frame.height / layoutSize.height,
        ) *
        1.02;
    final dx = frame.center.dx - (layoutSize.width * scale) / 2;
    final dy = frame.center.dy - (layoutSize.height * scale) / 2;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  /// Initial transform so the full image fits inside [frame] (contain fit).
  static Matrix4 containFrame({
    required Rect frame,
    required Size layoutSize,
  }) {
    return _containRegionInFrame(
      frame: frame,
      regionLayout: Offset.zero & layoutSize,
      margin: 0.95,
    );
  }

  /// Contain typical castle footprint (from a calibrated throne box) in [frame].
  static Matrix4 fitThroneAnchoredExtents({
    required Rect frame,
    required Size layoutSize,
    required Size imageSize,
    required Rect throneRectImage,
  }) {
    final tileW = throneRectImage.width / 2;
    final tileH = throneRectImage.height;
    if (tileW <= 0 || tileH <= 0) {
      return containFrame(frame: frame, layoutSize: layoutSize);
    }

    final castleW = tileW * CastleTypicalExtents.baseWidthWide;
    final cx = throneRectImage.center.dx;
    final top = throneRectImage.top -
        tileH * CastleTypicalExtents.tilesAboveGround;
    final bottom = throneRectImage.bottom +
        tileH * CastleTypicalExtents.tilesBelowGroundMax;
    final left = cx - castleW / 2;
    final right = cx + castleW / 2;

    final toLayout = 1.0 / layoutToImageScale(imageSize, layoutSize);
    final layoutBounds = Offset.zero & layoutSize;
    var regionLayout = Rect.fromLTRB(
      left * toLayout,
      top * toLayout,
      right * toLayout,
      bottom * toLayout,
    ).intersect(layoutBounds);
    if (regionLayout.width < 8 || regionLayout.height < 8) {
      regionLayout = layoutBounds;
    }

    return _containRegionInFrame(
      frame: frame,
      regionLayout: regionLayout,
      margin: 0.92,
    );
  }

  /// Bounds-step fit: throne-anchored footprint or full photo, whichever is
  /// more zoomed out so the whole castle can fit in the overlay.
  static Matrix4 fitBoundsStep({
    required Rect frame,
    required Size layoutSize,
    required Size imageSize,
    required Rect throneRectImage,
  }) {
    final anchored = fitThroneAnchoredExtents(
      frame: frame,
      layoutSize: layoutSize,
      imageSize: imageSize,
      throneRectImage: throneRectImage,
    );
    final full = containFrame(frame: frame, layoutSize: layoutSize);
    return anchored.getMaxScaleOnAxis() <= full.getMaxScaleOnAxis()
        ? anchored
        : full;
  }

  /// Minimum pinch scale for [InteractiveViewer].
  ///
  /// Must be **at or below** the programmatic initial [initialTransform] scale;
  /// otherwise the first pinch snaps inward to [minScale] and the user loses
  /// zoom-out range.
  static double viewerMinScale({
    required Size layoutSize,
    required Size viewport,
    required Matrix4 initialTransform,
  }) {
    final initial = initialTransform.getMaxScaleOnAxis();
    final fullPhoto = math.min(
      viewport.width / layoutSize.width,
      viewport.height / layoutSize.height,
    );
    return math.min(0.01, math.min(initial * 0.45, fullPhoto * 0.85));
  }

  static double interactiveMinScale(Size layoutSize, Size viewport) {
    final fitAll = math.min(
      viewport.width / layoutSize.width,
      viewport.height / layoutSize.height,
    );
    return math.min(0.01, fitAll * 0.5);
  }

  static Matrix4 _containRegionInFrame({
    required Rect frame,
    required Rect regionLayout,
    double margin = 0.92,
  }) {
    if (regionLayout.width <= 0 || regionLayout.height <= 0) {
      return Matrix4.identity();
    }
    final scale = math.min(
          frame.width / regionLayout.width,
          frame.height / regionLayout.height,
        ) *
        margin;
    final dx = frame.center.dx - regionLayout.center.dx * scale;
    final dy = frame.center.dy - regionLayout.center.dy * scale;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }
}

/// Decode [sourcePath], crop to [crop] (image pixels), write JPEG to [destPath].
Future<String> writeCastleFrameCrop({
  required String sourcePath,
  required String destPath,
  required Rect crop,
}) async {
  final bytes = await File(sourcePath).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Could not decode image for framing crop');
  }

  final x = crop.left.floor().clamp(0, decoded.width - 1);
  final y = crop.top.floor().clamp(0, decoded.height - 1);
  final w = crop.width.round().clamp(1, decoded.width - x);
  final h = crop.height.round().clamp(1, decoded.height - y);

  log('castle frame crop ${decoded.width}x${decoded.height} → '
      '${w}x$h @($x,$y)');

  final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
  final jpg = img.encodeJpg(cropped, quality: 92);
  final out = File(destPath);
  await out.parent.create(recursive: true);
  await out.writeAsBytes(jpg, flush: true);
  return destPath;
}

/// Load pixel size without full Flutter image provider.
///
/// Uses the Flutter codec so dimensions match [Image.file] on screen (EXIF
/// orientation applied).
Future<Size> decodeImagePixelSize(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final size = Size(image.width.toDouble(), image.height.toDouble());
  image.dispose();
  return size;
}

/// Decode bitmap pixels in the same orientation the user sees when aligning
/// the photo (EXIF baked). Grid alignment rects must use this decoder.
///
/// [expectedSize] is the Flutter-codec size (same as [decodeImagePixelSize] /
/// [Image.file]). If package:image's EXIF bake does not match, we fall back
/// to the Flutter codec so crops line up with the grid the user marked.
Future<img.Image> decodeOrientedImage(
  String path, {
  Size? expectedSize,
}) async {
  final bytes = await File(path).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded != null) {
    final baked = img.bakeOrientation(decoded);
    if (baked.width != decoded.width || baked.height != decoded.height) {
      log('decodeOrientedImage EXIF bake '
          '${decoded.width}x${decoded.height} → ${baked.width}x${baked.height}');
    }
    if (expectedSize == null || _sizeMatches(baked, expectedSize)) {
      return baked;
    }
    log('decodeOrientedImage size mismatch vs display '
        '${baked.width}x${baked.height} vs '
        '${expectedSize.width.round()}x${expectedSize.height.round()} '
        '— using Flutter codec');
  } else {
    log('decodeOrientedImage: package:image failed; using Flutter codec');
  }

  return _decodeViaFlutterCodec(bytes);
}

bool _sizeMatches(img.Image image, Size expected) {
  return (image.width - expected.width.round()).abs() <= 1 &&
      (image.height - expected.height.round()).abs() <= 1;
}

Future<img.Image> _decodeViaFlutterCodec(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final uiImage = frame.image;
  final width = uiImage.width;
  final height = uiImage.height;
  final bd = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
  uiImage.dispose();
  if (bd == null) {
    throw StateError('Could not decode image via Flutter codec');
  }
  final rgba = bd.buffer.asUint8List();
  final out = img.Image(width: width, height: height);
  var i = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      out.setPixelRgba(x, y, rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]);
      i += 4;
    }
  }
  return out;
}
