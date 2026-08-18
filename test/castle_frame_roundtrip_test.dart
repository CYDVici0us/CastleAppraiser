import 'dart:math' as math;

import 'package:btcc/src/tflite/tile_selection_geom.dart';
import 'package:btcc/src/utils/castle_frame_crop.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

/// Simulate InteractiveViewer pan then zoom (scale about focal point).
Matrix4 _panZoomMatrix(
  Matrix4 base,
  Offset panViewport,
  double zoomFactor,
  Offset focalViewport,
) {
  var m = base.clone();
  // Pan: translate in scene space (same as InteractiveViewer boundary-free).
  m.translateByDouble(panViewport.dx, panViewport.dy, 0, 1);

  // Zoom about focal point (simplified InteractiveViewer scale).
  final inv = Matrix4.inverted(m);
  final focalScene = MatrixUtils.transformPoint(inv, focalViewport);
  m.scaleByDouble(zoomFactor, zoomFactor, zoomFactor, 1);
  final inv2 = Matrix4.inverted(m);
  final focalScene2 = MatrixUtils.transformPoint(inv2, focalViewport);
  m.translateByDouble(
    focalScene2.dx - focalScene.dx,
    focalScene2.dy - focalScene.dy,
    0,
    1,
  );
  return m;
}

Matrix4 _markStepFit({
  required Size viewport,
  required Size imageSize,
  required Size layoutSize,
  required Rect boundsRect,
}) {
  final toLayout = CastleFrameGeom.layoutToImageScale(imageSize, layoutSize);
  final bLeft = boundsRect.left / toLayout;
  final bTop = boundsRect.top / toLayout;
  final bW = boundsRect.width / toLayout;
  final bH = boundsRect.height / toLayout;
  final scale = math.min(viewport.width / bW, viewport.height / bH) * 0.80;
  final dx = viewport.width / 2 - (bLeft + bW / 2) * scale;
  final dy = viewport.height / 2 - (bTop + bH / 2) * scale;
  return Matrix4.identity()
    ..translateByDouble(dx, dy, 0, 1)
    ..scaleByDouble(scale, scale, scale, 1);
}

Offset _imageToViewport(
  Offset imagePoint,
  Matrix4 transform, {
  required Size imageSize,
  required Size layoutSize,
}) {
  final s = layoutSize.width / imageSize.width;
  return MatrixUtils.transformPoint(
    transform,
    Offset(imagePoint.dx * s, imagePoint.dy * s),
  );
}

void main() {
  group('bounds pan/zoom round-trip', () {
    const viewport = Size(400, 650);
    const imageSize = Size(3024, 4032);
    final layout = CastleFrameGeom.displayLayoutSize(imageSize, viewport);

    test('throne grid cells stay square after bounds pan/zoom', () {
      final throneFrame = CastleFrameGeom.frameRectAspect(viewport, 2.0);
      final boundsFrame = CastleFrameGeom.frameRectAspect(
        viewport,
        8 / 11,
        maxHeightFraction: 0.82,
      );

      const throneImage = Rect.fromLTWH(900, 2800, 200, 100);

      // Throne step: cover fit, no user adjustment.
      final throneTransform = CastleFrameGeom.coverFrame(
        frame: throneFrame,
        layoutSize: layout,
      );
      final throneRect = CastleFrameGeom.imageCropRect(
        frame: throneFrame,
        transform: throneTransform,
        imageWidth: imageSize.width.round(),
        imageHeight: imageSize.height.round(),
        layoutSize: layout,
      );

      // Bounds step: auto fit then user pan/zoom.
      final boundsBase = CastleFrameGeom.fitBoundsStep(
        frame: boundsFrame,
        layoutSize: layout,
        imageSize: imageSize,
        throneRectImage: throneRect,
      );
      final boundsTransform = _panZoomMatrix(
        boundsBase,
        const Offset(35, -50),
        1.35,
        boundsFrame.center,
      );
      final boundsRect = CastleFrameGeom.imageCropRect(
        frame: boundsFrame,
        transform: boundsTransform,
        imageWidth: imageSize.width.round(),
        imageHeight: imageSize.height.round(),
        layoutSize: layout,
      );

      final cal = TileSelectionCalibration(
        imagePath: 'test.jpg',
        throneRect: throneRect,
        boundsRect: boundsRect,
      );

      final markTransform = _markStepFit(
        viewport: viewport,
        imageSize: imageSize,
        layoutSize: layout,
        boundsRect: boundsRect,
      );

      // Grid cell (0,0) should map to a viewport rect matching tile aspect.
      final cell = cal.cellRect(const GridCell(0, 0));
      final tl = _imageToViewport(
        cell.topLeft,
        markTransform,
        imageSize: imageSize,
        layoutSize: layout,
      );
      final br = _imageToViewport(
        cell.bottomRight,
        markTransform,
        imageSize: imageSize,
        layoutSize: layout,
      );
      final vw = (br.dx - tl.dx).abs();
      final vh = (br.dy - tl.dy).abs();
      expect(vw, closeTo(vh, 0.5), reason: 'cell should appear square');

      // Tap round-trip: viewport center of cell → same grid cell.
      final center = Offset((tl.dx + br.dx) / 2, (tl.dy + br.dy) / 2);
      final back = CastleFrameGeom.viewportToImage(
        center,
        markTransform,
        imageSize: imageSize,
        layoutSize: layout,
      );
      expect(
        cal.cellAtImagePoint(back),
        const GridCell(0, 0),
      );
    });

    test('mark step stays aligned when viewport/layout changes after bounds crop', () {
      const boundsViewport = Size(400, 650);
      const markViewport = Size(400, 706); // mark step lacks portrait toggle row
      final boundsLayout =
          CastleFrameGeom.displayLayoutSize(imageSize, boundsViewport);
      final markLayout =
          CastleFrameGeom.displayLayoutSize(imageSize, markViewport);
      expect(boundsLayout, isNot(markLayout));

      final boundsFrame = CastleFrameGeom.frameRectAspect(
        boundsViewport,
        8 / 11,
        maxHeightFraction: 0.82,
      );
      const throneRect = Rect.fromLTWH(900, 2800, 200, 100);
      var t = CastleFrameGeom.fitBoundsStep(
        frame: boundsFrame,
        layoutSize: boundsLayout,
        imageSize: imageSize,
        throneRectImage: throneRect,
      );
      t = _panZoomMatrix(t, const Offset(20, -30), 1.2, boundsFrame.center);

      final boundsRect = CastleFrameGeom.imageCropRect(
        frame: boundsFrame,
        transform: t,
        imageWidth: imageSize.width.round(),
        imageHeight: imageSize.height.round(),
        layoutSize: boundsLayout,
      );

      final cal = TileSelectionCalibration(
        imagePath: 'test.jpg',
        throneRect: throneRect,
        boundsRect: boundsRect,
      );
      final markTransform = _markStepFit(
        viewport: markViewport,
        imageSize: imageSize,
        layoutSize: markLayout,
        boundsRect: boundsRect,
      );

      final cell = cal.cellRect(const GridCell(1, 0));
      final tl = _imageToViewport(
        cell.topLeft,
        markTransform,
        imageSize: imageSize,
        layoutSize: markLayout,
      );
      final br = _imageToViewport(
        cell.bottomRight,
        markTransform,
        imageSize: imageSize,
        layoutSize: markLayout,
      );
      final vw = (br.dx - tl.dx).abs();
      final vh = (br.dy - tl.dy).abs();
      expect(vw, closeTo(vh, 0.5));
    });

    test('crop must use same layout size as active transform', () {
      const viewport = Size(400, 650);
      final layoutA = CastleFrameGeom.displayLayoutSize(imageSize, viewport);
      final layoutB = Size(layoutA.width * 1.1, layoutA.height * 1.1);
      final frame = CastleFrameGeom.frameRectAspect(viewport, 8 / 11);
      final t = CastleFrameGeom.coverFrame(frame: frame, layoutSize: layoutA);

      final correct = CastleFrameGeom.imageCropRect(
        frame: frame,
        transform: t,
        imageWidth: imageSize.width.round(),
        imageHeight: imageSize.height.round(),
        layoutSize: layoutA,
      );
      final wrong = CastleFrameGeom.imageCropRect(
        frame: frame,
        transform: t,
        imageWidth: imageSize.width.round(),
        imageHeight: imageSize.height.round(),
        layoutSize: layoutB,
      );
      expect(correct, isNot(wrong));
    });

    test('frame center maps to bounds interior after pan/zoom crop', () {
      final boundsFrame = CastleFrameGeom.frameRectAspect(
        viewport,
        8 / 11,
        maxHeightFraction: 0.82,
      );
      const throneRect = Rect.fromLTWH(900, 2800, 200, 100);
      final base = CastleFrameGeom.fitBoundsStep(
        frame: boundsFrame,
        layoutSize: layout,
        imageSize: imageSize,
        throneRectImage: throneRect,
      );
      final t = _panZoomMatrix(
        base,
        const Offset(-80, 40),
        0.75,
        boundsFrame.center,
      );
      final crop = CastleFrameGeom.imageCropRect(
        frame: boundsFrame,
        transform: t,
        imageWidth: imageSize.width.round(),
        imageHeight: imageSize.height.round(),
        layoutSize: layout,
      );

      final frameCenterImage = CastleFrameGeom.viewportToImage(
        boundsFrame.center,
        t,
        imageSize: imageSize,
        layoutSize: layout,
      );
      expect(crop.contains(frameCenterImage), isTrue);
    });
  });
}
