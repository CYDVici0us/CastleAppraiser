import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/token_tile_grid.dart';
import 'package:test/test.dart';

void main() {
  group('TokenTileGrid', () {
    test('extract pulls bonus and royal and clears cells', () {
      final grid = GridList<Tile>(4, [
        BCPerFood(),
        RoyalAttendantJester(),
        Empty(),
        Empty(),
        Empty(),
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        Empty(),
        Empty(),
        Empty(),
        Empty(),
        Empty(),
      ]);

      final result = TokenTileGrid.extractTokenTiles(
        grid,
        getEmpty: () => Empty(),
      );

      expect(result.tokens.length, 2);
      expect(result.tokens[0].isBonusCard(), isTrue);
      expect(result.tokens[1].isRoyalAttendant(), isTrue);
      expect(result.structural.items[0].isEmpty(), isTrue);
      expect(result.structural.items[1].isEmpty(), isTrue);
      expect(result.structural.items[5].tileType, TileType.ThroneRoom);
    });

    test('merge puts tokens above structural without touching rooms', () {
      final structural = GridList<Tile>(4, [
        Empty(), Empty(), Empty(), Empty(),
        Empty(), ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
        Empty(), Empty(), Empty(), Empty(),
      ]);
      final tokens = <Tile>[BCPerFood(), RoyalAttendantKnight()];

      final merged = TokenTileGrid.mergeTokenTilesIntoGrid(
        structural,
        tokens,
        getEmpty: () => Empty(),
      );

      expect(merged.width, 4);
      expect(merged.height, 4); // 3 + 1 token row
      expect(merged.items[0].id, tokens[0].id);
      expect(merged.items[1].id, tokens[1].id);
      // Structural top empty row is now row 1
      expect(merged.items[4].isEmpty(), isTrue);
      // Throne shifted down one row: was index 5, now 5+4=9
      expect(merged.items[9].tileType, TileType.ThroneRoom);
    });

    test('extract closes vertical gaps toward ground', () {
      // Bonus between rooms above throne — after extract, kitchen falls down.
      // width 3:
      // Kitchen
      // Bonus
      // Throne Placeholder _
      final grid = GridList<Tile>(3, [
        Kitchen(), Empty(), Empty(),
        BCPerFood(), Empty(), Empty(),
        ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
      ]);

      final result = TokenTileGrid.extractTokenTiles(
        grid,
        getEmpty: () => Empty(),
      );

      expect(result.tokens.single.isBonusCard(), isTrue);
      // Kitchen should pack just above throne (row 1)
      expect(result.structural.items[3].id, TileId.Kitchen);
      expect(result.structural.items[0].isEmpty(), isTrue);
      expect(result.structural.items[6].tileType, TileType.ThroneRoom);
    });

    test('extract closes below-ground gaps upward', () {
      // Throne on row 0, bonus then dungeon below — dungeon rises.
      final grid = GridList<Tile>(3, [
        ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
        BCPerFood(), Empty(), Empty(),
        Dungeon(), Empty(), Empty(),
      ]);

      final result = TokenTileGrid.extractTokenTiles(
        grid,
        getEmpty: () => Empty(),
      );

      expect(result.tokens.single.isBonusCard(), isTrue);
      expect(result.structural.items[3].id, TileId.Dungeon);
      expect(result.structural.items[6].isEmpty(), isTrue);
    });

    test('extract closes ground-row gap beside throne', () {
      // Room | Bonus | Throne | PH  on one row — room slides next to throne.
      final grid = GridList<Tile>(4, [
        Empty(), Empty(), Empty(), Empty(),
        Kitchen(), BCPerFood(), ThroneRoomPerCorridorFood(), Placeholder(),
        Empty(), Empty(), Empty(), Empty(),
      ]);

      final result = TokenTileGrid.extractTokenTiles(
        grid,
        getEmpty: () => Empty(),
      );

      expect(result.tokens.single.isBonusCard(), isTrue);
      // Kitchen packs to throneX-1 (index 5)
      expect(result.structural.items[5].id, TileId.Kitchen);
      expect(result.structural.items[4].isEmpty(), isTrue);
      expect(result.structural.items[6].tileType, TileType.ThroneRoom);
    });

    test('extract closes ground-row gap to the right of placeholder', () {
      // Throne | PH | Bonus | Hall — hall slides next to placeholder.
      final grid = GridList<Tile>(4, [
        Empty(), Empty(), Empty(), Empty(),
        ThroneRoomPerCorridorFood(), Placeholder(), BCPerFood(), GreatHall(),
        Empty(), Empty(), Empty(), Empty(),
      ]);

      final result = TokenTileGrid.extractTokenTiles(
        grid,
        getEmpty: () => Empty(),
      );

      expect(result.tokens.single.isBonusCard(), isTrue);
      expect(result.structural.items[6].id, TileId.GreatHall);
      expect(result.structural.items[7].isEmpty(), isTrue);
    });
  });
}
