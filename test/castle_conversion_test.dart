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
