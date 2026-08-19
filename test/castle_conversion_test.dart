import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/castle_conversion.dart';
import 'package:btcc/src/tflite/castle_occupancy.dart';
import 'package:btcc/src/tflite/throne_anchored_lattice.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:test/test.dart';

TfliteProcessedGuess g({
  required TileLabels label,
  required double x,
  required double y,
  double w = 90,
  double h = 80,
  double score = 0.9,
}) {
  return TfliteProcessedGuess(
    xMin: x,
    xMax: x + w,
    yMin: y,
    yMax: y + h,
    label: label,
    probability: score,
    confidence: 1,
    score: score,
  );
}

void main() {
  group('CastleConversion throne-anchored', () {
    test('places rooms on throne lattice and grows grid for wings', () {
      final throne = g(
        label: TileLabels.TRCD,
        x: 400,
        y: 400,
        w: 200,
        h: 80,
      );
      final leftRoom = g(label: TileLabels.KITCHEN, x: 305, y: 405, w: 90, h: 80);
      final rightRoom = g(label: TileLabels.LOFT, x: 605, y: 405, w: 90, h: 80);

      final result = CastleConversion.convertGuessesToCastleWithInfo([
        throne,
        leftRoom,
        rightRoom,
      ]);

      expect(
        result.grid.items.any((t) => t.id == TileId.Kitchen),
        isTrue,
      );
      expect(
        result.grid.items.any((t) => t.id == TileId.Loft),
        isTrue,
      );
      expect(
        result.grid.items.any((t) => t.tileType == TileType.ThroneRoom),
        isTrue,
      );
    });

    test('interior false bonus becomes unidentified occupied cell', () {
      final throne = g(
        label: TileLabels.TRCD,
        x: 400,
        y: 400,
        w: 200,
        h: 80,
      );
      final room = g(label: TileLabels.KITCHEN, x: 400, y: 300, w: 90, h: 80);
      final falseBonus = g(
        label: TileLabels.BCFOOD,
        x: 510,
        y: 310,
        w: 70,
        h: 60,
        score: 0.85,
      );

      final result = CastleConversion.convertGuessesToCastleWithInfo([
        throne,
        room,
        falseBonus,
      ]);

      expect(result.unidentifiedOccupiedCount, greaterThan(0));
    });

    test('unique Kitchen is not placed twice on neighboring cells', () {
      final throne = g(
        label: TileLabels.TRCD,
        x: 400,
        y: 400,
        w: 200,
        h: 80,
      );
      final kitchenA = g(
        label: TileLabels.KITCHEN,
        x: 305,
        y: 405,
        score: 0.95,
      );
      final kitchenB = g(
        label: TileLabels.KITCHEN,
        x: 200,
        y: 200,
        score: 0.7,
      );
      final loft = g(label: TileLabels.LOFT, x: 605, y: 405, score: 0.8);

      final result = CastleConversion.convertGuessesToCastleWithInfo([
        throne,
        kitchenA,
        kitchenB,
        loft,
      ]);
      final kitchens =
          result.grid.items.where((t) => t.id == TileId.Kitchen).length;
      expect(kitchens, 1);
    });

    test('two ball rooms of the same type are allowed', () {
      final throne = g(
        label: TileLabels.TRCD,
        x: 400,
        y: 400,
        w: 200,
        h: 80,
      );
      final br1 = g(label: TileLabels.BRD, x: 305, y: 405, score: 0.9);
      final br2 = g(label: TileLabels.BRD, x: 605, y: 405, score: 0.85);

      final result = CastleConversion.convertGuessesToCastleWithInfo([
        throne,
        br1,
        br2,
      ]);
      final ballRooms = result.grid.items
          .where((t) =>
              t.id == TileId.BallRoomPerDownstairs ||
              t.id == TileId.BallRoomPerDownstairs2)
          .length;
      expect(ballRooms, 2);
    });

    test('morphological closing fills surrounded hole', () {
      final occupied = <(int, int)>{
        (0, 0),
        (1, 0),
        (0, 1),
        (2, 1),
        (0, 2),
        (1, 2),
      };
      final closed = CastleOccupancy.morphologicalClosing(occupied);
      expect(closed.contains((1, 1)), isTrue);
    });
  });

  group('ThroneAnchoredLattice', () {
    test('refinePitch nudges origin from residuals', () {
      const lattice = ThroneAnchoredLattice(
        originX: 100,
        originY: 200,
        tileW: 50,
        tileH: 40,
      );
      final refined = lattice.refinePitch(
        samples: [(0, -1, 130.0, 180.0)],
      );
      expect(refined.originX, isNot(100));
      expect(refined.tileW, 50);
    });

    test('refinePitch shrinks a fat throne so west rooms keep their cell', () {
      const fat = ThroneAnchoredLattice(
        originX: 380,
        originY: 400,
        tileW: 120,
        tileH: 80,
      );
      // True pitch is 100, origin 400. Centers of gx -4,-2,-1,2,3.
      const centers = <(double cx, double cy)>[
        (50, 440),
        (250, 440),
        (350, 440),
        (650, 440),
        (750, 440),
      ];
      expect(fat.cellForCenter(50, 440), ( -3, 0 ));

      final samples = [
        for (final c in centers)
          (
            fat.cellForCenter(c.$1, c.$2).$1,
            fat.cellForCenter(c.$1, c.$2).$2,
            c.$1,
            c.$2,
          ),
      ];
      final refined = fat.refinePitch(samples: samples);
      expect(refined.cellForCenter(50, 440), ( -4, 0 ));
      expect(refined.cellForCenter(250, 440), ( -2, 0 ));
      expect(refined.cellForCenter(350, 440), ( -1, 0 ));
      expect(refined.cellForCenter(650, 440), ( 2, 0 ));
    });

    test('refinePitch corrects vertical tileH from multi-row detections', () {
      // Wizard estimates tileH = 80, but true vertical pitch is 100.
      // Two rows of detections at gy=0 and gy=-1 give enough vertical pairs.
      const lat = ThroneAnchoredLattice(
        originX: 400,
        originY: 400,
        tileW: 100,
        tileH: 80,
      );

      // Ground row (gy=0): centers at y=440 (400 + 0.5*80)
      // Row above (gy=-1): true y should be 300 (400 - 100 + 50) but with
      // tileH=80 the lattice puts gy=-1 at y=360. Detections land at true
      // positions so their centers are at y=350 (= 400 - 100 + 50).
      final samples = <(int, int, double, double)>[
        // gy=0 rooms
        (lat.cellForCenter(450, 440).$1, lat.cellForCenter(450, 440).$2, 450, 440),
        (lat.cellForCenter(550, 440).$1, lat.cellForCenter(550, 440).$2, 550, 440),
        (lat.cellForCenter(650, 440).$1, lat.cellForCenter(650, 440).$2, 650, 440),
        // gy=-1 rooms (true y center = 350)
        (lat.cellForCenter(450, 350).$1, lat.cellForCenter(450, 350).$2, 450, 350),
        (lat.cellForCenter(550, 350).$1, lat.cellForCenter(550, 350).$2, 550, 350),
      ];

      final refined = lat.refinePitch(samples: samples);
      // Vertical pitch should be closer to ~90-100 rather than the original 80.
      expect(refined.tileH, greaterThan(85));
      expect(refined.tileH, lessThanOrEqualTo(100));
    });
  });

  group('getCorrectTile exhaustion', () {
    test('sixth fountain throws', () {
      final tiles = <Tile>[];
      for (var i = 0; i < 5; i++) {
        tiles.add(
          TfliteHelper.getCorrectTile(
            g(label: TileLabels.FOUNTAIN, x: 0, y: 0),
            tiles,
          ),
        );
      }
      expect(
        () => TfliteHelper.getCorrectTile(
          g(label: TileLabels.FOUNTAIN, x: 0, y: 0),
          tiles,
        ),
        throwsException,
      );
    });

    test('second unique Kitchen throws', () {
      final first = TfliteHelper.getCorrectTile(
        g(label: TileLabels.KITCHEN, x: 0, y: 0),
        const <Tile>[],
      );
      expect(
        () => TfliteHelper.getCorrectTile(
          g(label: TileLabels.KITCHEN, x: 100, y: 0),
          <Tile>[first],
        ),
        throwsException,
      );
    });
  });
}
