import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/castle_typical_extents.dart';
import 'package:btcc/src/tflite/content_band.dart';
import 'package:btcc/src/tflite/letterbox_coords.dart';
import 'package:btcc/src/tflite/rotation_order.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:btcc/src/utils/statistics_helper.dart';
import 'package:test/test.dart';

TfliteProcessedGuess guess({
  required TileLabels label,
  required double xMin,
  required double xMax,
  required double yMin,
  required double yMax,
  double score = 0.9,
}) {
  return TfliteProcessedGuess(
    xMin: xMin,
    xMax: xMax,
    yMin: yMin,
    yMax: yMax,
    label: label,
    probability: score,
    confidence: 1.0,
    score: score,
  );
}

void main() {
  group('BRD mapping', () {
    test('BRD maps to BallRoomPerDownstairs not Outdoor', () {
      final tile = TfliteHelper.getCorrectTile(
        guess(
          label: TileLabels.BRD,
          xMin: 0,
          xMax: 10,
          yMin: 0,
          yMax: 10,
        ),
        <Tile>[],
      );
      expect(tile.id, TileId.BallRoomPerDownstairs);
    });

    test('second BRD maps to BallRoomPerDownstairs2', () {
      final first = TfliteHelper.getCorrectTile(
        guess(
          label: TileLabels.BRD,
          xMin: 0,
          xMax: 10,
          yMin: 0,
          yMax: 10,
        ),
        <Tile>[],
      );
      final second = TfliteHelper.getCorrectTile(
        guess(
          label: TileLabels.BRD,
          xMin: 20,
          xMax: 30,
          yMin: 0,
          yMax: 10,
        ),
        <Tile>[first],
      );
      expect(second.id, TileId.BallRoomPerDownstairs2);
    });

    test('BRO still maps to Outdoor', () {
      final tile = TfliteHelper.getCorrectTile(
        guess(
          label: TileLabels.BRO,
          xMin: 0,
          xMax: 10,
          yMin: 0,
          yMax: 10,
        ),
        <Tile>[],
      );
      expect(tile.id, TileId.BallRoomPerOutdoor);
    });
  });

  group('GuessStats', () {
    test('excludes bonus/attendants from extents and averages', () {
      final rooms = [
        guess(
          label: TileLabels.KITCHEN,
          xMin: 100,
          xMax: 200,
          yMin: 100,
          yMax: 200,
        ),
        guess(
          label: TileLabels.WAITING_ROOM,
          xMin: 200,
          xMax: 300,
          yMin: 100,
          yMax: 200,
        ),
        guess(
          label: TileLabels.TRCD,
          xMin: 150,
          xMax: 350,
          yMin: 200,
          yMax: 300,
        ),
      ];
      final withTokens = [
        ...rooms,
        guess(
          label: TileLabels.BCREGULAR,
          xMin: 0,
          xMax: 50,
          yMin: 0,
          yMax: 80,
          score: 0.95,
        ),
        guess(
          label: TileLabels.RAM,
          xMin: 900,
          xMax: 980,
          yMin: 900,
          yMax: 980,
          score: 0.94,
        ),
      ];

      final statsRooms = GuessStats.getGuessStats(rooms);
      final statsAll = GuessStats.getGuessStats(withTokens);

      expect(statsAll.minX, statsRooms.minX);
      expect(statsAll.maxX, statsRooms.maxX);
      expect(statsAll.minY, statsRooms.minY);
      expect(statsAll.maxY, statsRooms.maxY);
      expect(statsAll.averageX, closeTo(statsRooms.averageX, 0.001));
      expect(statsAll.averageY, closeTo(statsRooms.averageY, 0.001));
    });

    test('throne-only still yields positive averages', () {
      final stats = GuessStats.getGuessStats([
        guess(
          label: TileLabels.TRCD,
          xMin: 100,
          xMax: 300,
          yMin: 100,
          yMax: 200,
        ),
      ]);
      expect(stats.averageX, greaterThan(0));
      expect(stats.averageY, greaterThan(0));
      expect(stats.averageX, closeTo(100, 0.001));
      expect(stats.averageY, closeTo(100, 0.001));
    });
  });

  group('score-aware placement', () {
    test('higher score wins when two rooms map to same cell', () {
      final grid = TfliteHelper.convertGuessesToCastle([
        guess(
          label: TileLabels.WAITING_ROOM,
          xMin: 100,
          xMax: 200,
          yMin: 100,
          yMax: 200,
          score: 0.5,
        ),
        guess(
          label: TileLabels.KITCHEN,
          xMin: 100,
          xMax: 200,
          yMin: 100,
          yMax: 200,
          score: 0.99,
        ),
        guess(
          label: TileLabels.TRCD,
          xMin: 200,
          xMax: 400,
          yMin: 200,
          yMax: 300,
          score: 0.9,
        ),
      ]);

      final kitchenCount =
          grid.items.where((t) => t.id == TileId.Kitchen).length;
      final waitingCount =
          grid.items.where((t) => t.id == TileId.WaitingRoom).length;
      expect(kitchenCount, 1);
      expect(waitingCount, 0);
    });
  });

  group('StatHelper outliers', () {
    test('median ignores a single extreme size', () {
      expect(StatHelper.getMedian([10, 10, 10, 10, 1000]), 10);
    });

    test('identical values still return the value', () {
      expect(StatHelper.getAverageRemoveOutlier([5, 5, 5]), 5);
      expect(StatHelper.getMedian([5, 5, 5]), 5);
    });
  });

  group('classAwareNms', () {
    test('keeps adjacent different labels that share edge IoU', () {
      // Neighboring tiles with IoU above sameClassIou — class-agnostic NMS
      // would drop the second; class-aware keeps both.
      final a = guess(
        label: TileLabels.FOUNTAIN,
        xMin: 0,
        xMax: 100,
        yMin: 0,
        yMax: 100,
        score: 0.95,
      );
      final b = guess(
        label: TileLabels.AVIARY,
        xMin: 35,
        xMax: 135,
        yMin: 0,
        yMax: 100,
        score: 0.9,
      );
      expect(a.calculateOverlap(b), greaterThan(0.45));
      final kept = TfliteHelper.classAwareNms([a, b], sameClassIou: 0.45);
      expect(kept.length, 2);
    });

    test('suppresses duplicate same-label boxes', () {
      final a = guess(
        label: TileLabels.FOUNTAIN,
        xMin: 0,
        xMax: 100,
        yMin: 0,
        yMax: 100,
        score: 0.95,
      );
      final b = guess(
        label: TileLabels.FOUNTAIN,
        xMin: 10,
        xMax: 110,
        yMin: 10,
        yMax: 110,
        score: 0.8,
      );
      final kept = TfliteHelper.classAwareNms([a, b], sameClassIou: 0.45);
      expect(kept.length, 1);
      expect(kept.first.score, 0.95);
    });

    test('suppresses different labels only when nearly identical boxes', () {
      final a = guess(
        label: TileLabels.FOUNTAIN,
        xMin: 0,
        xMax: 100,
        yMin: 0,
        yMax: 100,
        score: 0.95,
      );
      final b = guess(
        label: TileLabels.AVIARY,
        xMin: 5,
        xMax: 105,
        yMin: 5,
        yMax: 105,
        score: 0.9,
      );
      expect(a.calculateOverlap(b), greaterThan(0.7));
      final kept = TfliteHelper.classAwareNms(
        [a, b],
        sameClassIou: 0.45,
        crossClassIou: 0.7,
      );
      expect(kept.length, 1);
      expect(kept.first.label, TileLabels.FOUNTAIN);
    });
  });

  group('letterbox undo', () {
    test('portrait pad: left content edge maps near x=0', () {
      // 2496×3328 → pad 3329 with ox=416, oy=0; input 1664; no rotate.
      final g = LetterboxGeom.fromSource(
        srcW: 2496,
        srcH: 3328,
        inputSize: 1664,
        rotations: 0,
      );
      expect(g.ox, 416);
      expect(g.oy, 0);
      // Left edge of content in model space after resize.
      final mx = 416 * 1664 / 3329;
      final (x, y) = undoLetterboxPoint(mx, 100, g);
      expect(x, closeTo(0, 1.5));
      expect(y, closeTo(100 * 3329 / 1664 - 0, 2));
    });

    test('portrait pad: right content edge maps near srcW', () {
      final g = LetterboxGeom.fromSource(
        srcW: 2496,
        srcH: 3328,
        inputSize: 1664,
        rotations: 0,
      );
      final mx = (416 + 2496) * 1664 / 3329;
      final (x, _) = undoLetterboxPoint(mx, 100, g);
      expect(x, closeTo(2496, 2));
    });

    test('small crop pads to model input instead of upscaling', () {
      final g = LetterboxGeom.fromSource(
        srcW: 496,
        srcH: 520,
        inputSize: 1664,
        rotations: 0,
      );
      expect(g.padSize, 1664);
      expect(g.ox, (1664 - 496) ~/ 2);
      expect(g.oy, (1664 - 520) ~/ 2);
    });

    test('round-trip CW rotation undoes inside the square', () {
      final g = LetterboxGeom.fromSource(
        srcW: 2000,
        srcH: 3000,
        inputSize: 1000,
        rotations: 1,
      );
      // Point in source near center-left.
      const sx = 100.0;
      const sy = 1500.0;
      // Forward: pad → resize → CW once, then undo should recover.
      final padX = sx + g.ox;
      final padY = sy + g.oy;
      final mx0 = padX * g.inputSize / g.padSize;
      final my0 = padY * g.inputSize / g.padSize;
      // One CW: (x,y) → (H-y, x) with H=inputSize for square.
      final mx = g.inputSize - my0;
      final my = mx0;
      final (rx, ry) = undoLetterboxPoint(mx, my, g);
      expect(rx, closeTo(sx, 2));
      expect(ry, closeTo(sy, 2));
    });
  });

  group('content band crop', () {
    test('tall portrait forces near-square full-width window', () {
      // 1080×2400 with a tall center tower — band should be ~1080 tall.
      final crop = computeContentBandCrop(
        imageW: 1080,
        imageH: 2400,
        minX: 400,
        maxX: 680,
        minY: 200,
        maxY: 2100,
        avgTileW: 80,
        avgTileH: 80,
      );
      expect(crop, isNotNull);
      expect(crop!.x, 0);
      expect(crop.width, 1080);
      expect(crop.height, lessThan(2400 * 0.92));
      expect(crop.height, closeTo(1080, 120));
    });

    test('near-square frame returns null', () {
      final crop = computeContentBandCrop(
        imageW: 1000,
        imageH: 1050,
        minX: 100,
        maxX: 900,
        minY: 100,
        maxY: 900,
        avgTileW: 80,
        avgTileH: 80,
      );
      expect(crop, isNull);
    });

    test('wide landscape forces near-square full-height window', () {
      final crop = computeContentBandCrop(
        imageW: 2400,
        imageH: 1080,
        minX: 200,
        maxX: 2200,
        minY: 400,
        maxY: 680,
        avgTileW: 80,
        avgTileH: 80,
      );
      expect(crop, isNotNull);
      expect(crop!.y, 0);
      expect(crop.height, 1080);
      expect(crop.width, lessThan(2400 * 0.92));
      expect(crop.width, closeTo(1080, 120));
    });
  });

  group('castle typical extents', () {
    test('expandDetectionBounds grows small pass-1 tower to ~10×10 tiles', () {
      final b = CastleTypicalExtents.expandDetectionBounds(
        minX: 480,
        maxX: 600,
        minY: 500,
        maxY: 900,
        avgTileW: 80,
        avgTileH: 80,
        imageW: 1080,
        imageH: 1400,
      );
      expect(b.maxY - b.minY, closeTo(80 * CastleTypicalExtents.verticalSpanMaxTiles, 120));
      expect(b.maxX - b.minX, closeTo(80 * CastleTypicalExtents.baseWidthWide, 120));
    });

    test('wing strip width caps at ~38% of frame', () {
      final strip = CastleTypicalExtents.wingStripWidthPx(
        imageW: 3000,
        avgTileW: 540,
      );
      expect(strip, lessThan(3000 * 0.4));
      expect(strip, greaterThan(900));
    });
  });

  group('zoom+pan plan', () {
    test('portrait plans left and right full-height strips when under quad threshold', () {
      final plan = planZoomPanCrops(
        imageW: 1080,
        imageH: 1000,
        minX: 400,
        maxX: 680,
        minY: 400,
        maxY: 900,
        avgTileW: 80,
        avgTileH: 120, // 10 rows ≈ 1200px — just under quad split at 0.85
        maxCrops: 4,
      );
      expect(plan.reason, 'portrait-lr');
      expect(plan.crops.length, 2);
      expect(plan.crops[0].tag, 'zoom-left');
      expect(plan.crops[1].tag, 'zoom-right');
      expect(plan.crops[0].height, 1000);
      expect(plan.crops[0].width, lessThan(1080));
    });

    test('typical ~10-row portrait uses upper+lower wing pans per side', () {
      final plan = planZoomPanCrops(
        imageW: 1080,
        imageH: 1400,
        minX: 400,
        maxX: 680,
        minY: 400,
        maxY: 1000,
        avgTileW: 80,
        avgTileH: 80,
      );
      expect(plan.reason, 'portrait-lr-quad');
      expect(plan.crops.length, 4);
      expect(plan.crops.map((c) => c.tag).toSet(), {
        'zoom-left-top',
        'zoom-left-bot',
        'zoom-right-top',
        'zoom-right-bot',
      });
    });

    test('very tall portrait uses upper+lower wing pans per side', () {
      final plan = planZoomPanCrops(
        imageW: 1080,
        imageH: 2400, // > 1.45 * width
        minX: 400,
        maxX: 680,
        minY: 900,
        maxY: 1500,
        avgTileW: 80,
        avgTileH: 80,
      );
      expect(plan.reason, 'portrait-lr-quad');
      expect(plan.crops.length, 4);
      expect(plan.crops.map((c) => c.tag).toSet(), {
        'zoom-left-top',
        'zoom-left-bot',
        'zoom-right-top',
        'zoom-right-bot',
      });
      for (final c in plan.crops) {
        expect(c.height, greaterThan(1080 * 0.5));
      }
    });

    test('wide-span portrait still uses wing zooms', () {
      final plan = planZoomPanCrops(
        imageW: 1080,
        imageH: 1400,
        minX: 40,
        maxX: 1040,
        minY: 400,
        maxY: 1000,
        avgTileW: 80,
        avgTileH: 80,
        maxCrops: 2,
      );
      expect(plan.reason, 'portrait-lr');
      expect(plan.crops.length, 2);
    });

    test('landscape plans top and bottom full-width strips', () {
      final plan = planZoomPanCrops(
        imageW: 1400,
        imageH: 1080,
        minX: 400,
        maxX: 1000,
        minY: 400,
        maxY: 680,
        avgTileW: 80,
        avgTileH: 80,
      );
      expect(plan.reason, 'landscape-tb');
      expect(plan.crops.length, 2);
      expect(plan.crops[0].tag, 'zoom-top');
      expect(plan.crops[1].tag, 'zoom-bottom');
      expect(plan.crops[0].width, 1400);
    });

    test('very wide landscape uses corner pans', () {
      final plan = planZoomPanCrops(
        imageW: 2400,
        imageH: 1080,
        minX: 200,
        maxX: 2200,
        minY: 400,
        maxY: 680,
        avgTileW: 80,
        avgTileH: 80,
      );
      expect(plan.reason, 'landscape-tb-quad');
      expect(plan.crops.length, 4);
    });

    test('respects maxCrops=1', () {
      final plan = planZoomPanCrops(
        imageW: 1080,
        imageH: 2400,
        minX: 400,
        maxX: 680,
        minY: 900,
        maxY: 1500,
        avgTileW: 80,
        avgTileH: 80,
        maxCrops: 1,
      );
      expect(plan.crops.length, lessThanOrEqualTo(1));
    });
  });

  group('throne salvage', () {
    test('classAwareNms keeps throne when attendant overlaps it', () {
      final throne = guess(
        label: TileLabels.TRCD,
        xMin: 100,
        xMax: 300,
        yMin: 100,
        yMax: 200,
        score: 0.6,
      );
      final attendant = guess(
        label: TileLabels.RAM,
        xMin: 140,
        xMax: 200,
        yMin: 110,
        yMax: 170,
        score: 0.95,
      );
      expect(throne.calculateOverlap(attendant), greaterThan(0.15));
      final kept = TfliteHelper.classAwareNms([attendant, throne]);
      expect(kept.any((g) => g.label == TileLabels.TRCD), isTrue);
      expect(kept.any((g) => g.label == TileLabels.RAM), isTrue);
    });

    test('inferThroneFromAttendants places ~2-wide box under RA', () {
      final inferred = TfliteHelper.inferThroneFromAttendants([
        guess(
          label: TileLabels.RAM,
          xMin: 200,
          xMax: 260,
          yMin: 150,
          yMax: 210,
          score: 0.9,
        ),
        guess(
          label: TileLabels.KITCHEN,
          xMin: 100,
          xMax: 200,
          yMin: 100,
          yMax: 200,
          score: 0.8,
        ),
      ]);
      expect(inferred, isNotNull);
      expect(inferred!.label, TileLabels.TRCD);
      expect(inferred.xMax - inferred.xMin, closeTo(200, 1));
    });

    test('convertGuessesToCastle opens with inferred throne', () {
      final grid = TfliteHelper.convertGuessesToCastle([
        guess(
          label: TileLabels.RAM,
          xMin: 200,
          xMax: 260,
          yMin: 150,
          yMax: 210,
          score: 0.95,
        ),
        guess(
          label: TileLabels.KITCHEN,
          xMin: 100,
          xMax: 200,
          yMin: 100,
          yMax: 200,
          score: 0.9,
        ),
        guess(
          label: TileLabels.WAITING_ROOM,
          xMin: 300,
          xMax: 400,
          yMin: 100,
          yMax: 200,
          score: 0.85,
        ),
      ]);
      expect(
        grid.items.any((t) => t.tileType == TileType.ThroneRoom),
        isTrue,
      );
    });
  });

  group('modernRotationOrder', () {
    test('covers all four turns', () {
      final order = modernRotationOrder(
        preferred: 0,
        landscapeBitmap: true,
      );
      expect(order.toSet(), {0, 1, 2, 3});
      expect(order.first, 0);
    });

    test('landscape with odd EXIF still tries upright 0 early', () {
      final order = modernRotationOrder(
        preferred: 3,
        landscapeBitmap: true,
      );
      expect(order.first, 3);
      expect(order.indexOf(0), lessThan(3));
      expect(order.toSet().length, 4);
    });

    test('old preferred+2-alts gap is closed (0 no longer skips 3)', () {
      final order = modernRotationOrder(
        preferred: 0,
        landscapeBitmap: true,
      );
      expect(order.contains(3), isTrue);
    });
  });

  group('expected room tile count', () {
    test('countRoomDetections excludes throne and tokens', () {
      final guesses = [
        guess(label: TileLabels.KITCHEN, score: 0.9),
        guess(label: TileLabels.TRCD, score: 0.95),
        guess(label: TileLabels.RAT, score: 0.8),
        guess(label: TileLabels.BRC, score: 0.7),
      ];
      expect(TfliteHelper.countRoomDetections(guesses), 1);
    });

    test('isUnderExpectedRoomCount when below target', () {
      expect(TfliteHelper.isUnderExpectedRoomCount(14, 22), isTrue);
      expect(TfliteHelper.isUnderExpectedRoomCount(22, 22), isFalse);
      expect(TfliteHelper.isUnderExpectedRoomCount(10, null), isFalse);
    });
  });
}

