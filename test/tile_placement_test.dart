import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/tile_placement.dart';
import 'package:test/test.dart';

/// Compact castle: width 4
/// Row0: Empty, Kitchen, Empty, Empty          (above)
/// Row1: Empty, Throne, Placeholder, Empty     (ground)
/// Row2: Empty, Dungeon, Empty, Empty          (below)
GridList<Tile> _baseCastle({
  Tile? aboveThrone,
  Tile? leftOfThrone,
  Tile? belowThrone,
  Tile? rightOfPlaceholder,
}) {
  return GridList<Tile>(4, [
    Empty(),
    aboveThrone ?? Empty(),
    Empty(),
    Empty(),
    leftOfThrone ?? Empty(),
    ThroneRoomPerCorridorFood(),
    Placeholder(),
    rightOfPlaceholder ?? Empty(),
    Empty(),
    belowThrone ?? Empty(),
    Empty(),
    Empty(),
  ]);
}

void main() {
  group('TilePlacement ground and levels', () {
    test('groundRow is throne row', () {
      final grid = _baseCastle();
      expect(TilePlacement.groundRow(grid), 1);
      expect(TilePlacement.levelRelativeToGround(grid, 1), CastleLevel.above);
      expect(TilePlacement.levelRelativeToGround(grid, 5), CastleLevel.ground);
      expect(TilePlacement.levelRelativeToGround(grid, 9), CastleLevel.below);
    });

    test('type allowed by level', () {
      expect(
        TilePlacement.isTypeAllowedAtLevel(TileType.Food, CastleLevel.above),
        isTrue,
      );
      expect(
        TilePlacement.isTypeAllowedAtLevel(TileType.Food, CastleLevel.below),
        isFalse,
      );
      expect(
        TilePlacement.isTypeAllowedAtLevel(
            TileType.Downstairs, CastleLevel.below),
        isTrue,
      );
      expect(
        TilePlacement.isTypeAllowedAtLevel(
            TileType.Downstairs, CastleLevel.ground),
        isFalse,
      );
      expect(
        TilePlacement.isTypeAllowedAtLevel(
            TileType.Corridor, CastleLevel.below),
        isTrue,
      );
      expect(
        TilePlacement.isTypeAllowedAtLevel(TileType.Secret, CastleLevel.above),
        isTrue,
      );
      expect(
        TilePlacement.isTypeAllowedAtLevel(TileType.Secret, CastleLevel.below),
        isTrue,
      );
    });

    test('picker types exclude downstairs above ground', () {
      final above = TilePlacement.allowedPickerTypesForLevel(CastleLevel.above);
      expect(above, isNot(contains(TileType.Downstairs)));
      expect(above, contains(TileType.Food));
      expect(above, contains(TileType.Secret));

      final below = TilePlacement.allowedPickerTypesForLevel(CastleLevel.below);
      expect(below, contains(TileType.Downstairs));
      expect(below, contains(TileType.Corridor));
      expect(below, contains(TileType.Secret));
      expect(below, isNot(contains(TileType.Food)));
    });
  });

  group('TilePlacement canPlaceTile', () {
    test('requires support above ground when requireSupport is true', () {
      final grid = _baseCastle();
      // Index 0 is above an empty cell — no support
      expect(
        TilePlacement.canPlaceTile(grid, 0, Kitchen(), requireSupport: true),
        isFalse,
      );
      // Allowed when soft-placing (badge later instead of blocking)
      expect(
        TilePlacement.canPlaceTile(grid, 0, Kitchen(), requireSupport: false),
        isTrue,
      );
      // Index 1 is directly above the throne — supported
      expect(
        TilePlacement.canPlaceTile(grid, 1, Kitchen()),
        isTrue,
      );
    });

    test('blocks downstairs on ground and food below', () {
      final grid = _baseCastle(belowThrone: Empty());
      expect(
        TilePlacement.canPlaceTile(grid, 5, Dungeon(), requireSupport: false),
        isFalse,
      );
      expect(
        TilePlacement.canPlaceTile(grid, 9, Kitchen()),
        isFalse,
      );
      expect(
        TilePlacement.canPlaceTile(grid, 9, Dungeon()),
        isTrue,
      );
      expect(
        TilePlacement.canPlaceTile(grid, 9, ThroughTheWardrobe()),
        isTrue,
      );
    });

    test('blocks tile above outdoor', () {
      final grid = _baseCastle(aboveThrone: Biergarten());
      // Index 1 is outdoor; index above outdoor would be - width = invalid.
      // Put outdoor at ground next to throne and try place above it.
      final withOutdoor = GridList<Tile>(4, [
        Empty(), Empty(), Empty(), Empty(),
        Empty(), ThroneRoomPerCorridorFood(), Placeholder(), Biergarten(),
        Empty(), Empty(), Empty(), Empty(),
      ]);
      // Cell above outdoor (index 7-4=3)
      expect(TilePlacement.isDirectlyAboveOutdoor(withOutdoor, 3), isTrue);
      expect(
        TilePlacement.canPlaceTile(withOutdoor, 3, Kitchen()),
        isFalse,
      );
    });
  });

  group('TilePlacement invalidReasons', () {
    test('flags above outdoor, unsupported, and wrong type', () {
      final grid = GridList<Tile>(4, [
        Kitchen(), Empty(), Empty(), Empty(), // floating food above
        Empty(), ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
        Dungeon(), Empty(), Empty(), Empty(),
      ]);
      // Index 0: kitchen above with no support below (empty at 4)
      expect(
        TilePlacement.invalidReasons(grid, 0),
        contains(PlacementInvalidReason.unsupportedAboveGround),
      );
      expect(TilePlacement.hasInvalidPlacement(grid, 0), isTrue);

      final stacked = GridList<Tile>(4, [
        Empty(), Kitchen(), Empty(), Empty(),
        Empty(), Biergarten(), Empty(), Empty(),
        Empty(), ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
      ]);
      // Throne at row 2; kitchen at 1 above outdoor at 5
      expect(
        TilePlacement.invalidReasons(stacked, 1),
        contains(PlacementInvalidReason.aboveOutdoor),
      );

      final wrongLevel = _baseCastle(belowThrone: Kitchen());
      expect(
        TilePlacement.invalidReasons(wrongLevel, 9),
        contains(PlacementInvalidReason.wrongTypeForLevel),
      );
    });
  });

  group('GridListNormalizer interior gaps', () {
    test('detects empty hole inside occupied bounds', () {
      // 3x3 content with center hole (plus we use a tight 3-wide block)
      final grid = GridList<Tile>(3, [
        Kitchen(), GreatHall(), Fountain(),
        Biergarten(), Empty(), ThroughTheWardrobe(),
        Dungeon(), GreatHall(), Kitchen(),
      ]);
      expect(
        GridListNormalizer.isEmptyInsideOccupiedBounds(
          grid,
          4,
          isOccupied: (t) => !t.isEmpty(),
        ),
        isTrue,
      );
      expect(
        GridListNormalizer.canPlaceAdjacent(
          grid,
          4,
          isOccupied: (t) => !t.isEmpty(),
        ),
        isTrue,
      );
    });
  });

  group('TilePlacement structural gaps', () {
    test('marks empty under unsupported upper room', () {
      final grid = GridList<Tile>(3, [
        Kitchen(), Empty(), Empty(),
        Empty(), Empty(), Empty(),
        ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
      ]);
      expect(
        TilePlacement.invalidReasons(grid, 3),
        contains(PlacementInvalidReason.structuralGap),
      );
      expect(TilePlacement.hasInvalidPlacement(grid, 3), isTrue);
      expect(
        TilePlacement.invalidReasons(grid, 0),
        contains(PlacementInvalidReason.unsupportedAboveGround),
      );
    });

    test('marks empty between rooms in a row', () {
      final grid = GridList<Tile>(4, [
        Empty(), Empty(), Empty(), Empty(),
        Kitchen(), Empty(), GreatHall(), Empty(),
        Empty(), ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
      ]);
      expect(
        TilePlacement.isInvalidStructuralGap(grid, 5),
        isTrue,
      );
    });

    test('does not mark perimeter empty as gap', () {
      final grid = _baseCastle(aboveThrone: Kitchen());
      // Index 0 is corner empty — not under kitchen (kitchen at 1)
      expect(TilePlacement.isInvalidStructuralGap(grid, 0), isFalse);
      expect(TilePlacement.isInvalidStructuralGap(grid, 3), isFalse);
    });
  });

  group('TilePlacement rotateSegment', () {
    test('closes gap when moving B onto D on a row', () {
      // Row: A B C D at indices 4..7 on width 4, with throne elsewhere
      final a = GreatHall();
      final b = Kitchen();
      final c = Fountain();
      final d = ThroughTheWardrobe();
      final grid = GridList<Tile>(4, [
        Empty(), Empty(), Empty(), Empty(),
        a, b, c, d,
        Empty(), ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
      ]);

      // Simulate drag of B: clear index 5
      final dragged = grid.items[5];
      grid.items[5] = Empty();

      expect(
        TilePlacement.rotateSegment(grid, 5, 7, dragged),
        isTrue,
      );
      expect(grid.items[4].id, a.id);
      expect(grid.items[5].id, c.id);
      expect(grid.items[6].id, d.id);
      expect(grid.items[7].id, b.id);
    });

    test('rejects diagonal rotate', () {
      final grid = _baseCastle(
        aboveThrone: Kitchen(),
        belowThrone: Dungeon(),
      );
      grid.items[1] = Empty(); // vacated kitchen at (1,0)
      // (0,2) is diagonal from (1,0)
      expect(
        TilePlacement.isDiagonal(grid, 1, 8),
        isTrue,
      );
      expect(
        TilePlacement.canRotateSegment(grid, 1, 8),
        isFalse,
      );
    });

    test('rejects rotate through throne', () {
      final grid = _baseCastle(
        leftOfThrone: Kitchen(),
        rightOfPlaceholder: GreatHall(),
      );
      // Kitchen at 4, hall at 7; segment crosses throne/placeholder
      grid.items[4] = Empty();
      expect(
        TilePlacement.canRotateSegment(grid, 4, 7),
        isFalse,
      );
    });

    test('compactTowardGround packs above and below toward throne row', () {
      final grid = GridList<Tile>(3, [
        Kitchen(), Empty(), Empty(),
        Empty(), Empty(), Empty(),
        ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
        Empty(), Empty(), Empty(),
        Dungeon(), Empty(), Empty(),
      ]);
      TilePlacement.compactTowardGround(grid, getEmpty: () => Empty());
      expect(grid.items[3].id, TileId.Kitchen); // just above throne
      expect(grid.items[0].isEmpty(), isTrue);
      expect(grid.items[9].id, TileId.Dungeon); // just below throne
      expect(grid.items[12].isEmpty(), isTrue);
    });

    test('orthogonal relocate crosses throne to fix wrong floor', () {
      // Dungeon wrongly above ground in col 0; empty below ground.
      final dungeon = Dungeon();
      final grid = GridList<Tile>(3, [
        dungeon, Empty(), Empty(),
        Empty(), Empty(), Empty(),
        ThroneRoomPerCorridorFood(), Placeholder(), Empty(),
        Empty(), Empty(), Empty(),
      ]);
      // Simulate drag: clear source
      grid.items[0] = Empty();
      final result = TilePlacement.tryOrthogonallyRelocate(
        grid,
        0,
        9,
        dungeon,
        canAddAt: (i) => grid.items[i].isEmpty(),
        canPlaceTile: (i, t) => TilePlacement.canPlaceTile(
          grid,
          i,
          t,
          requireSupport: false,
        ),
      );
      expect(result, OrthogonalMoveResult.relocated);
      expect(grid.items[9].id, TileId.Dungeon);
      TilePlacement.compactTowardGround(grid, getEmpty: () => Empty());
      // Packs just below throne
      expect(grid.items[9].id, TileId.Dungeon);
      expect(
        TilePlacement.invalidReasons(grid, 9),
        isNot(contains(PlacementInvalidReason.wrongTypeForLevel)),
      );
    });

    test('moving up from below does not push ground tile below', () {
      // Col 2: empty above, Kitchen on ground, Living wrongly below.
      // Moving Living up must not slide Kitchen below ground.
      final living = BrandyRoom(); // Living room
      final grid = GridList<Tile>(3, [
        Empty(), Empty(), Empty(),
        Empty(), Empty(), Empty(),
        ThroneRoomPerCorridorFood(), Placeholder(), Kitchen(),
        Empty(), Empty(), living,
      ]);
      grid.items[11] = Empty(); // clear source
      expect(
        TilePlacement.canRotateSegment(grid, 11, 2),
        isFalse,
        reason: 'must not rotate across ground (would push Kitchen below)',
      );
      final result = TilePlacement.tryOrthogonallyRelocate(
        grid,
        11,
        2,
        living,
        canAddAt: (i) => grid.items[i].isEmpty(),
        canPlaceTile: (i, t) => TilePlacement.canPlaceTile(
          grid,
          i,
          t,
          requireSupport: false,
        ),
      );
      expect(result, OrthogonalMoveResult.relocated);
      expect(grid.items[2].id, living.id);
      expect(grid.items[8].id, TileId.Kitchen);
      TilePlacement.compactTowardGround(grid, getEmpty: () => Empty());
      final ground = TilePlacement.groundRow(grid)!;
      for (int i = 0; i < grid.items.length; i++) {
        if (grid.items[i].id != TileId.Kitchen) continue;
        final y = i ~/ grid.width;
        expect(y <= ground, isTrue,
            reason: 'Kitchen must not end up below ground');
      }
    });
  });
}
