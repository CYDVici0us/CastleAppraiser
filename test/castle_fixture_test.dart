import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/castle_fixture.dart';
import 'package:btcc/src/tflite/cell_guess_info.dart';
import 'package:btcc/src/tflite/cell_guess_remap.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/token_tile_grid.dart';
import 'package:test/test.dart';

void main() {
  final helper = TileHelper();

  test('fixture export includes rooms, bonus cards, and attendants', () {
    final structural = GridList<Tile>(4, [
      Empty(),
      helper.getTileById(TileId.ThroneRoomPerCorridorDownstairs),
      Placeholder(),
      helper.getTileById(TileId.Kitchen),
    ]);
    final grid = TokenTileGrid.mergeTokenTilesIntoGrid(
      structural,
      [
        helper.getTileById(TileId.BCPerFood),
        helper.getTileById(TileId.RoyalAttendantJester),
        helper.getTileById(TileId.RoyalAttendantJester2),
      ],
      getEmpty: () => Empty(),
    );

    final fixture = CastleFixture.fromCastle(
      Castle(grid),
      imageFileName: '20260816_044725.jpg',
      fromAsset: true,
    );

    expect(fixture.image, '20260816_044725.jpg');
    expect(fixture.source, CastleFixture.sourceAsset);
    expect(fixture.jsonFileName, '20260816_044725.json');
    expect(fixture.expectedRooms, 1);
    expect(fixture.labels['0,0'], 'TRCD');
    expect(fixture.labels['2,0'], 'KITCHEN');
    expect(fixture.occupied, containsAll([
      [0, 0],
      [1, 0],
      [2, 0],
    ]));
    expect(fixture.bonus, ['BCFOOD']);
    expect(fixture.attendants, ['RAT', 'RAT']);
    expect(fixture.scan, isEmpty);
  });

  test('copy tiles export canonical detector labels', () {
    expect(labelFromTileId(TileId.Fountain2), TileLabels.FOUNTAIN);
    expect(labelFromTileId(TileId.BallRoomPerDownstairs2), TileLabels.BRD);
    expect(labelFromTileId(TileId.RoyalAttendantTaylor2), TileLabels.RAM);
  });

  test('photo source uses a new image filename', () {
    final grid = GridList<Tile>(3, [
      helper.getTileById(TileId.ThroneRoomPerCorridorDownstairs),
      Placeholder(),
      Empty(),
    ]);
    final fixture = CastleFixture.fromCastle(
      Castle(grid),
      imageFileName: 'castle_photo.jpg',
      fromAsset: false,
    );
    expect(fixture.source, CastleFixture.sourcePhoto);
    expect(fixture.image, 'castle_photo.jpg');
    expect(fixture.bonus, isEmpty);
    expect(fixture.attendants, isEmpty);
  });

  test('fixture diff reports occupancy and label mismatches', () {
    final golden = CastleFixture(
      image: 'a.jpg',
      source: CastleFixture.sourcePhoto,
      expectedRooms: 1,
      occupied: const [
        [0, 0],
        [1, 0],
        [2, 0],
      ],
      labels: const {'0,0': 'TRCD', '2,0': 'KITCHEN'},
      bonus: const ['BCFOOD'],
      attendants: const ['RAS', 'RAS'],
    );
    final actual = CastleFixture(
      image: 'a.jpg',
      source: CastleFixture.sourcePhoto,
      expectedRooms: 1,
      occupied: const [
        [0, 0],
        [1, 0],
        [3, 0],
      ],
      labels: const {'0,0': 'TRCD', '3,0': 'LOUNGE'},
      bonus: const [],
      attendants: const ['RAS'],
    );
    final diff = golden.diff(actual);
    expect(diff.missingOccupied, ['2,0']);
    expect(diff.extraOccupied, ['3,0']);
    expect(diff.missingLabels, ['2,0']);
    expect(diff.missingBonus, ['BCFOOD']);
    expect(diff.missingAttendants, ['RAS']);
    expect(diff.isPerfect, isFalse);
  });

  test('fixture export includes throne-relative scan metadata', () {
    final grid = GridList<Tile>(3, [
      helper.getTileById(TileId.ThroneRoomPerCorridorDownstairs),
      Placeholder(),
      helper.getTileById(TileId.Kitchen),
    ]);
    final castle = Castle(grid);
    castle.cellGuesses = {
      0: CellGuessInfo.fromGuess(score: 0.9, coverage: 0.8),
      2: CellGuessInfo.unidentifiedCell(alternatives: [TileLabels.KITCHEN]),
    };

    final fixture = CastleFixture.fromCastle(
      castle,
      imageFileName: 'scan.jpg',
      fromAsset: false,
    );

    expect(fixture.scan['0,0']!.level, GuessConfidenceLevel.high);
    expect(fixture.scan['2,0']!.unidentified, isTrue);
    expect(fixture.scan['2,0']!.alternatives, [TileLabels.KITCHEN]);

    final json = fixture.toJson();
    expect(json.containsKey('scan'), isTrue);
    final roundTrip = CastleFixture.fromJson(json);
    expect(roundTrip.scan['2,0']!.unidentified, isTrue);
    expect(roundTrip.scan['0,0']!.score, closeTo(0.9, 0.001));
  });

  test('scan json round-trips across a merged token row', () {
    final structural = GridList<Tile>(3, [
      helper.getTileById(TileId.ThroneRoomPerCorridorDownstairs),
      Placeholder(),
      helper.getTileById(TileId.Kitchen),
    ]);
    final guesses = {
      2: CellGuessInfo.fromGuess(score: 0.3, coverage: 0.2),
    };
    final encoded = encodeCellGuessesJson(structural, guesses);
    expect(encoded, isNotNull);

    final merged = TokenTileGrid.mergeTokenTilesIntoGrid(
      structural,
      [helper.getTileById(TileId.BCPerFood)],
      getEmpty: () => Empty(),
    );
    final decoded = decodeCellGuessesJson(merged, encoded);
    expect(decoded.length, 1);
    final kitchenIndex = merged.items.indexWhere((t) => t.id == TileId.Kitchen);
    expect(decoded[kitchenIndex]!.score, closeTo(0.3, 0.001));
  });
}
