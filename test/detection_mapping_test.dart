import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/letterbox.dart';
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
        // Far outside the castle — must not inflate extents.
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
      expect(stats.averageX, closeTo(100, 0.001)); // width/2
      expect(stats.averageY, closeTo(100, 0.001));
    });
  });

  group('score-aware placement', () {
    test('higher score wins when two rooms map to same cell', () {
      // Two rooms with identical boxes; kitchen has higher score and should win.
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

  group('letterbox mapping', () {
    test('square image rotations=0 is near identity scale', () {
      final geometry = LetterboxGeometry.fromImageSize(100, 100);
      // padSize = 101, ox=oy=0
      expect(geometry.padSize, 101);
      expect(geometry.ox, 0);
      expect(geometry.oy, 0);

      final mapped = mapModelBoxToImage(
        xMin: 10,
        xMax: 20,
        yMin: 30,
        yMax: 40,
        inputImageSize: 100,
        rotations: 0,
        geometry: geometry,
      );
      expect(mapped.valid, isTrue);
      // scale = 101/100 → slight expansion, no pad offset
      expect(mapped.xMin, closeTo(10 * 1.01, 0.05));
      expect(mapped.yMin, closeTo(30 * 1.01, 0.05));
    });

    test('portrait letterbox subtracts horizontal pad', () {
      final geometry = LetterboxGeometry.fromImageSize(50, 100);
      expect(geometry.padSize, 101);
      expect(geometry.ox, 25);
      expect(geometry.oy, 0);

      final mapped = mapModelBoxToImage(
        xMin: 50,
        xMax: 60,
        yMin: 40,
        yMax: 50,
        inputImageSize: 100,
        rotations: 0,
        geometry: geometry,
      );
      expect(mapped.valid, isTrue);
      // Center of model square maps near image x=25 (pad ox).
      expect(mapped.xMin, closeTo(50 * 1.01 - 25, 0.5));
    });

    test('edge overhang is clamped not rejected', () {
      final geometry = LetterboxGeometry.fromImageSize(100, 100);
      final mapped = mapModelBoxToImage(
        xMin: -5,
        xMax: 20,
        yMin: 10,
        yMax: 30,
        inputImageSize: 100,
        rotations: 0,
        geometry: geometry,
      );
      expect(mapped.valid, isTrue);
      expect(mapped.xMin, 0);
    });
  });
}
