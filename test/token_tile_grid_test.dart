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
        isTrue,
      );
      expect(withJester.where((t) => t.isRoyalAttendant()).length, 4);

      expect(
        TokenTileGrid.resolveTokenToAdd(
          RoyalAttendantJester(),
          [RoyalAttendantJester()],
        ).id,
        TileId.RoyalAttendantJester,
      );

      final twoAttendants = TokenTileGrid.filterTokenPickerTiles(
        inventory: inventory,
        currentTokens: [RoyalAttendantJester(), RoyalAttendantKnight()],
      );
      expect(twoAttendants.where((t) => t.isRoyalAttendant()).length, 4);
      expect(twoAttendants.where((t) => t.isBonusCard()).length, 3);

      final sevenJesters = List<Tile>.generate(
        TokenTileGrid.maxCopiesPerRoyalAttendantType,
        (_) => RoyalAttendantJester(),
      );
      final atJesterCap = TokenTileGrid.filterTokenPickerTiles(
        inventory: inventory,
        currentTokens: sevenJesters,
      );
      expect(
        atJesterCap.any((t) => t.name == 'RoyalAttendantJester'),
        isFalse,
      );
      expect(atJesterCap.where((t) => t.isRoyalAttendant()).length, 3);

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

    test('extract leaves vertical gaps when token sat among rooms', () {
      // Bonus between rooms above throne — kitchen stays above the gap.
      final grid = GridList<Tile>(3, [
        Kitchen(), Empty(), Empty(),
        BCPerFood(), Empty(), Empty(),
        ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
      ]);

      final result = TokenTileGrid.extractTokenTiles(
        grid,
        getEmpty: () => Empty(),
      );

      expect(result.tokens, isEmpty);
      expect(result.structural.items[0].id, TileId.Kitchen);
      expect(result.structural.items[3].isEmpty(), isTrue);
      expect(result.structural.items[6].tileType, TileType.ThroneRoom);
    });

    test('extract leaves below-ground gaps when token sat among rooms', () {
      final grid = GridList<Tile>(3, [
        ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
        BCPerFood(), Empty(), Empty(),
        Dungeon(), Empty(), Empty(),
      ]);

      final result = TokenTileGrid.extractTokenTiles(
        grid,
        getEmpty: () => Empty(),
      );

      expect(result.tokens, isEmpty);
      expect(result.structural.items[6].id, TileId.Dungeon);
      expect(result.structural.items[3].isEmpty(), isTrue);
    });

    test('extract leaves ground-row gap beside throne', () {
      final grid = GridList<Tile>(4, [
        Empty(), Empty(), Empty(), Empty(),
        Kitchen(), BCPerFood(), ThroneRoomPerCorridorFood(), Placeholder(),
        Empty(), Empty(), Empty(), Empty(),
      ]);

      final result = TokenTileGrid.extractTokenTiles(
        grid,
        getEmpty: () => Empty(),
      );

      expect(result.tokens, isEmpty);
      expect(result.structural.items[4].id, TileId.Kitchen);
      expect(result.structural.items[5].isEmpty(), isTrue);
      expect(result.structural.items[6].tileType, TileType.ThroneRoom);
    });

    test('extract of saved token strip does not pack rooms toward throne', () {
      // Saved merge: attendants on row 0, kitchen left of a gap beside throne.
      final grid = GridList<Tile>(5, [
        RoyalAttendantJester(), Empty(), Empty(), Empty(), Empty(),
        Empty(), Kitchen(), Empty(), ThroneRoomPerCorridorFood(), Placeholder(),
      ]);

      final result = TokenTileGrid.extractTokenTiles(
        grid,
        getEmpty: () => Empty(),
      );

      expect(result.tokens.single.isRoyalAttendant(), isTrue);
      expect(result.structural.items[6].id, TileId.Kitchen);
      expect(result.structural.items[7].isEmpty(), isTrue);
      expect(result.structural.items[8].tileType, TileType.ThroneRoom);
    });

    test('extract leaves ground-row gap to the right of placeholder', () {
      // Throne | PH | Bonus | Hall — gap stays after bonus is pulled out.
      final grid = GridList<Tile>(4, [
        Empty(), Empty(), Empty(), Empty(),
        ThroneRoomPerCorridorFood(), Placeholder(), BCPerFood(), GreatHall(),
        Empty(), Empty(), Empty(), Empty(),
      ]);

      final result = TokenTileGrid.extractTokenTiles(
        grid,
        getEmpty: () => Empty(),
      );

      expect(result.tokens, isEmpty);
      expect(result.structural.items[6].isEmpty(), isTrue);
      expect(result.structural.items[7].id, TileId.GreatHall);
    });

    test('extract still collects a side-column bonus card', () {
      final grid = GridList<Tile>(4, [
        Empty(), Empty(), Empty(), Empty(),
        Empty(), ThroneRoomPerCorridorFood(), Placeholder(), BCPerFood(),
        Empty(), Empty(), Empty(), Empty(),
      ]);

      final result = TokenTileGrid.extractTokenTiles(
        grid,
        getEmpty: () => Empty(),
      );

      expect(result.tokens.single.isBonusCard(), isTrue);
      expect(result.structural.items[7].isEmpty(), isTrue);
    });

    test('canonicalize moves stray bonus from a room cell onto the strip', () {
      final merged = TokenTileGrid.mergeTokenTilesIntoGrid(
        GridList<Tile>(4, [
          Empty(), Empty(), Empty(), Empty(),
          Empty(), ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
          Empty(), Empty(), Empty(), Empty(),
        ]),
        [BCPerFood()],
        getEmpty: () => Empty(),
      );
      // Misplaced bonus in an empty room cell (not gap-filling beside the throne).
      merged.items[11] = BCPerActivity();

      final fixed = TokenTileGrid.canonicalizeForPersistence(
        merged,
        getEmpty: () => Empty(),
      );

      expect(fixed.height, merged.height);
      expect(fixed.items[11].isEmpty(), isTrue);
      expect(fixed.items[0].isBonusCard(), isTrue);
      expect(fixed.items[1].isBonusCard(), isTrue);
    });

    test('displayName humanizes specials and ball rooms', () {
      expect(
        TokenTileGrid.displayName(BallRoomPerUtility()),
        'Ball Room',
      );
      expect(
        TokenTileGrid.displayName(BallRoomPerFood()),
        'Ball Room',
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
