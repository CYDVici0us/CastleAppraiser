import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/castle_fixture.dart';
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
}
