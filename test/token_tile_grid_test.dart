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
      // Tokens left-aligned in the visual top row
      expect(merged.items[0].id, tokens[0].id);
      expect(merged.items[1].id, tokens[1].id);
      expect(merged.items[2].isEmpty(), isTrue);
      expect(merged.items[3].isEmpty(), isTrue);
      // Structural top empty row is now row 1
      expect(merged.items[4].isEmpty(), isTrue);
      // Throne shifted down one row: was index 5, now 5+4=9
      expect(merged.items[9].tileType, TileType.ThroneRoom);
    });

    test('token picker shows 4 attendant types and respects max slots', () {
      final inventory = <Tile>[
        RoyalAttendantJester(),
        RoyalAttendantJester2(),
        RoyalAttendantKnight(),
        RoyalAttendantKnight2(),
        RoyalAttendantPainter(),
        RoyalAttendantPainter2(),
        RoyalAttendantTaylor(),
        RoyalAttendantTaylor2(),
        BCPerFood(),
        BCPerActivity(),
        BCPerSleeping(),
      ];

      final empty = TokenTileGrid.filterTokenPickerTiles(
        inventory: inventory,
        currentTokens: const [],
      );
      expect(
        empty.where((t) => t.isRoyalAttendant()).map((t) => t.id).toSet(),
        {
          TileId.RoyalAttendantTaylor,
          TileId.RoyalAttendantJester,
          TileId.RoyalAttendantKnight,
          TileId.RoyalAttendantPainter,
        },
      );
      expect(empty.where((t) => t.isBonusCard()).length, 3);

      final withJester = TokenTileGrid.filterTokenPickerTiles(
        inventory: inventory,
        currentTokens: [RoyalAttendantJester()],
      );
      expect(
        withJester.any((t) => t.name == 'RoyalAttendantJester'),
        isFalse,
      );
      expect(withJester.where((t) => t.isRoyalAttendant()).length, 3);

      final atAttendantCap = TokenTileGrid.filterTokenPickerTiles(
        inventory: inventory,
        currentTokens: [RoyalAttendantJester(), RoyalAttendantKnight()],
      );
      expect(atAttendantCap.where((t) => t.isRoyalAttendant()), isEmpty);
      expect(atAttendantCap.where((t) => t.isBonusCard()).length, 3);

      final atBonusCap = TokenTileGrid.filterTokenPickerTiles(
        inventory: inventory,
        currentTokens: [BCPerFood(), BCPerActivity()],
      );
      expect(atBonusCap.where((t) => t.isBonusCard()), isEmpty);
      expect(atBonusCap.where((t) => t.isRoyalAttendant()).length, 4);

      // Updating a bonus frees that slot for other cards.
      final replacingBonus = TokenTileGrid.filterTokenPickerTiles(
        inventory: inventory,
        currentTokens: [BCPerFood(), BCPerActivity()],
        replacing: BCPerFood(),
      );
      expect(replacingBonus.any((t) => t.id == TileId.BCPerSleeping), isTrue);
      expect(replacingBonus.any((t) => t.id == TileId.BCPerActivity), isFalse);
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

    test('displayName humanizes specials and ball rooms', () {
      expect(
        TokenTileGrid.displayName(BallRoomPerUtility()),
        'Ball Room · Utility',
      );
      expect(
        TokenTileGrid.displayName(BallRoomPerFood()),
        'Ball Room · Food',
      );
      expect(TokenTileGrid.displayName(Tower()), 'Tower');
      expect(TokenTileGrid.displayName(GrandFoyer()), 'Grand Foyer');
      expect(
        TokenTileGrid.scoringDescription(BallRoomPerUtility()),
        '+1 per Utility in neighboring castles',
      );
      expect(
        TokenTileGrid.scoringDescription(Tower()),
        '+1 per room below',
      );
      expect(
        TokenTileGrid.scoringDescription(Fountain()),
        '+5',
      );
      expect(
        TokenTileGrid.scoringDescription(GrandFoyer()),
        '+1 per surrounding room',
      );
    });
  });
}
