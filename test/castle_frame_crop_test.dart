import 'dart:math' as math;

import 'package:btcc/src/tflite/castle_typical_extents.dart';
import 'package:btcc/src/utils/castle_frame_crop.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {
  group('CastleFrameGeom', () {
    test('portrait frame is taller than wide', () {
      final frame = CastleFrameGeom.frameRect(
        const Size(400, 800),
        portrait: true,
      );
      expect(
        frame.height / frame.width,
        closeTo(1 / CastleTypicalExtents.portraitFrameAspect, 0.01),
      );
      expect(frame.center.dx, closeTo(200, 1));
    });

    test('landscape frame is wider than tall', () {
      final frame = CastleFrameGeom.frameRect(
        const Size(400, 800),
        portrait: false,
      );
      expect(
        frame.width / frame.height,
        closeTo(CastleTypicalExtents.landscapeFrameAspect, 0.01),
      );
    });

    test('identity transform maps frame corners into image space', () {
      const frame = Rect.fromLTWH(50, 100, 200, 150);
      const layout = Size(1000, 800);
      final crop = CastleFrameGeom.imageCropRect(
        frame: frame,
        transform: Matrix4.identity(),
        imageWidth: 1000,
        imageHeight: 800,
        layoutSize: layout,
      );
      // Inflated slightly, still near the frame.
      expect(crop.left, lessThan(50));
      expect(crop.top, lessThan(100));
      expect(crop.width, greaterThan(200));
      expect(crop.height, greaterThan(150));
    });

    test('coverFrame scales so both axes cover the frame', () {
      final frame = CastleFrameGeom.frameRect(
        const Size(400, 800),
        portrait: true,
      );
      final m = CastleFrameGeom.coverFrame(
        frame: frame,
        layoutSize: const Size(2000, 1000),
      );
      // Image width 2000 scaled should be >= frame width.
      final scale = m.getMaxScaleOnAxis();
      expect(2000 * scale, greaterThanOrEqualTo(frame.width));
      expect(1000 * scale, greaterThanOrEqualTo(frame.height));
    });

    test('containFrame scales so image fits inside frame', () {
      final frame = CastleFrameGeom.frameRect(
        const Size(400, 800),
        portrait: true,
      );
      const layout = Size(2000, 1000);
      final m = CastleFrameGeom.containFrame(frame: frame, layoutSize: layout);
      final scale = m.getMaxScaleOnAxis();
      expect(2000 * scale, lessThanOrEqualTo(frame.width));
      expect(1000 * scale, lessThanOrEqualTo(frame.height));
    });

    test('fitThroneAnchoredExtents zooms out for tall castle footprint', () {
      final frame = CastleFrameGeom.frameRect(
        const Size(400, 800),
        portrait: true,
      );
      const layout = Size(1200, 1600);
      const image = Size(1200, 1600);
      const throne = Rect.fromLTWH(500, 900, 200, 100);
      final cover = CastleFrameGeom.coverFrame(
        frame: frame,
        layoutSize: layout,
      );
      final fit = CastleFrameGeom.fitThroneAnchoredExtents(
        frame: frame,
        layoutSize: layout,
        imageSize: image,
        throneRectImage: throne,
      );
      expect(
        fit.getMaxScaleOnAxis(),
        lessThan(cover.getMaxScaleOnAxis()),
      );
    });

    test('viewerMinScale stays below initial fit scale', () {
      const layout = Size(1800, 2400);
      const viewport = Size(400, 700);
      final frame = CastleFrameGeom.frameRect(
        viewport,
        portrait: true,
      );
      const image = Size(1800, 2400);
      const throne = Rect.fromLTWH(700, 1800, 200, 100);
      final fit = CastleFrameGeom.fitBoundsStep(
        frame: frame,
        layoutSize: layout,
        imageSize: image,
        throneRectImage: throne,
      );
      final minScale = CastleFrameGeom.viewerMinScale(
        layoutSize: layout,
        viewport: viewport,
        initialTransform: fit,
      );
      expect(minScale, lessThanOrEqualTo(fit.getMaxScaleOnAxis()));
      expect(minScale, lessThanOrEqualTo(0.01));
    });

    test('interactiveMinScale allows zooming out past full photo', () {
      const layout = Size(1800, 2400);
      const viewport = Size(400, 700);
      final fitAll = math.min(
        viewport.width / layout.width,
        viewport.height / layout.height,
      );
      final minScale = CastleFrameGeom.interactiveMinScale(layout, viewport);
      expect(minScale, lessThanOrEqualTo(fitAll));
      expect(minScale, lessThanOrEqualTo(0.01));
    });

    test('displayLayoutSize caps huge photos for pan/zoom', () {
      const image = Size(4032, 3024);
      const viewport = Size(400, 700);
      final layout = CastleFrameGeom.displayLayoutSize(image, viewport);
      expect(layout.width, lessThan(image.width));
      expect(
        math.max(layout.width, layout.height),
        lessThanOrEqualTo(math.max(viewport.width, viewport.height) * 3),
      );
    });
  });
}
