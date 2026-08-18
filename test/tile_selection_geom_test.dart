import 'dart:ui';

import 'package:btcc/src/tflite/tile_selection_geom.dart';
import 'package:test/test.dart';

void main() {
  group('TileSelectionCalibration', () {
    test('cellAtImagePoint maps image coords to grid cell', () {
      const cal = TileSelectionCalibration(
        imagePath: 'x.jpg',
        throneRect: Rect.fromLTWH(100, 200, 200, 80),
        boundsRect: Rect.fromLTWH(0, 0, 1000, 1200),
      );
      expect(cal.tileWidth, 100);
      expect(cal.tileHeight, 80);
      expect(
        cal.cellAtImagePoint(const Offset(150, 240)),
        const GridCell(0, 0),
      );
      expect(
        cal.cellAtImagePoint(const Offset(250, 240)),
        const GridCell(1, 0),
      );
      expect(
        cal.cellAtImagePoint(const Offset(150, 120)),
        const GridCell(0, -1),
      );
    });

    test('gridBounds computes extent of marked cells', () {
      final bounds = TileSelectionCalibration.gridBounds({
        const GridCell(0, 0),
        const GridCell(1, 0),
        const GridCell(-1, 0),
        const GridCell(0, 2),
      });
      expect(bounds.minX, -1);
      expect(bounds.minY, 0);
      expect(bounds.width, 3);
      expect(bounds.height, 3);
    });

    test('countMarkedRoomTiles excludes throne and placeholder only', () {
      expect(
        countMarkedRoomTiles({
          const GridCell(0, 0),
          const GridCell(1, 0),
          const GridCell(-1, 0),
          const GridCell(2, 0),
          const GridCell(0, -1),
          const GridCell(0, 1),
        }),
        4,
      );
    });

    test('contextRect is several tiles around the cell', () {
      const cal = TileSelectionCalibration(
        imagePath: 'x.jpg',
        throneRect: Rect.fromLTWH(400, 400, 200, 80),
        boundsRect: Rect.fromLTWH(0, 0, 2000, 1600),
      );
      final r = cal.contextRect(
        const GridCell(0, -1),
        imageW: 2000,
        imageH: 1600,
        padTiles: 3,
      );
      expect(r.width, greaterThan(cal.tileWidth * 6));
      expect(r.height, greaterThan(cal.tileHeight * 6));
    });

    test('scoringContextRect is about 8 tiles on a side', () {
      const cal = TileSelectionCalibration(
        imagePath: 'x.jpg',
        throneRect: Rect.fromLTWH(400, 400, 200, 80),
        boundsRect: Rect.fromLTWH(0, 0, 2000, 1600),
      );
      final r = cal.scoringContextRect(
        const GridCell(0, 0),
        imageW: 2000,
        imageH: 1600,
      );
      expect(r.width, closeTo(cal.tileWidth * 8, 2));
      expect(r.height, closeTo(cal.tileWidth * 8, 2));
      expect(r.contains(cal.cellCenter(const GridCell(0, 0))), isTrue);
    });
  });
}
