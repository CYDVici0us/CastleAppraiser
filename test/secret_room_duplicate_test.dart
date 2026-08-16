import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Castle.refreshSecretRoomDuplicates', () {
    test('binds secret to the room its arrow points at', () {
      // width 3: secret (S) points south at kitchen
      // [Empty, TR, PH]
      // [Empty, ClimbTheLadder(S), Empty]
      // [Empty, Kitchen, Empty]
      final secret = ClimbTheLadder();
      final kitchen = Kitchen();
      final grid = GridList<Tile>(3, [
        Empty(),
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        Empty(),
        secret,
        Empty(),
        Empty(),
        kitchen,
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.refreshSecretRoomDuplicates();

      expect(secret.duplicate?.id, kitchen.id);
      expect(secret.tileType, TileType.Food);
    });

    test('rebinds when the pointed-to neighbor is replaced', () {
      final secret = WithinTheWalls(); // points East
      final kitchen = Kitchen();
      final brewery = Brewery();
      final grid = GridList<Tile>(3, [
        Empty(),
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        secret,
        kitchen,
        Empty(),
        Empty(),
        Empty(),
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.refreshSecretRoomDuplicates();
      expect(secret.duplicate?.id, kitchen.id);

      grid.items[4] = brewery;
      castle.refreshSecretRoomDuplicates();
      expect(secret.duplicate?.id, brewery.id);
      expect(secret.tileType, brewery.tileType);
    });

    test('clears duplicate when neighbor is removed', () {
      final secret = BehindTheBookCase(); // points West
      final kitchen = Kitchen();
      final grid = GridList<Tile>(3, [
        Empty(),
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        kitchen,
        secret,
        Empty(),
        Empty(),
        Empty(),
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.refreshSecretRoomDuplicates();
      expect(secret.duplicate?.id, kitchen.id);

      grid.items[3] = Empty();
      castle.refreshSecretRoomDuplicates();
      expect(secret.duplicate, isNull);
      expect(secret.tileType, TileType.Secret);
    });

    test('rebinds after secret is moved to a new cell', () {
      final secret = RideTheDumbWaiter(); // points North
      final kitchen = Kitchen();
      final brewery = Brewery();
      // Row0: Empty, TR, PH
      // Row1: kitchen, Empty, brewery
      // Row2: secret (under kitchen), Empty, Empty
      final grid = GridList<Tile>(3, [
        Empty(),
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        kitchen,
        Empty(),
        brewery,
        secret,
        Empty(),
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.refreshSecretRoomDuplicates();
      expect(secret.duplicate?.id, kitchen.id);

      // Move secret under brewery (same column as brewery).
      grid.items[6] = Empty();
      grid.items[8] = secret;
      castle.refreshSecretRoomDuplicates();
      expect(secret.duplicate?.id, brewery.id);
    });

    test('scoreCastle re-resolves after neighbor change on re-score', () {
      final secret = ClimbTheLadder(); // points South
      final kitchen = Kitchen();
      final brewery = Brewery();
      final grid = GridList<Tile>(3, [
        Empty(),
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        Empty(),
        secret,
        Empty(),
        Empty(),
        kitchen,
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.scoreCastle([]);
      // score clears duplicate after; refresh to inspect binding mid-layout
      castle.refreshSecretRoomDuplicates();
      expect(secret.duplicate?.id, kitchen.id);

      grid.items[7] = brewery;
      castle.scoreCastle([]);
      castle.refreshSecretRoomDuplicates();
      expect(secret.duplicate?.id, brewery.id);
    });
  });

  group('Secret scoring without a copy target', () {
    test('scores 0, counts as Secret, and appears on the score card', () {
      // ClimbTheLadder points South into empty — no copy.
      final secret = ClimbTheLadder();
      final bonus = BCPerSecret();
      final grid = GridList<Tile>(3, [
        bonus,
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        Empty(),
        secret,
        Empty(),
        Empty(),
        Empty(),
        Empty(),
      ]);
      final castle = Castle(grid);
      final total = castle.scoreCastle([]);

      expect(castle.tileScores[secret.id], 0);
      expect(castle.totalSecret, 1);
      expect(castle.castleScoreCard!.secret[secret.id], 0);
      // Bonus still sees the uncopied Secret as a Secret room.
      expect(castle.tileScores[bonus.id], bonus.scorePer);
      expect(total, bonus.scorePer);
    });

    test('copied Secret still tracks as Secret and scores like the target', () {
      final secret = ClimbTheLadder(); // South
      final kitchen = Kitchen();
      final bonus = BCPerSecret();
      final grid = GridList<Tile>(3, [
        bonus,
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        Empty(),
        secret,
        Empty(),
        Empty(),
        kitchen,
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.scoreCastle([]);

      expect(castle.totalSecret, 1);
      expect(castle.castleScoreCard!.secret.containsKey(secret.id), isTrue);
      expect(castle.tileScores[secret.id], isNot(0));
      expect(castle.tileScores[bonus.id], bonus.scorePer);
    });
  });

  group('Secret → Secret chains', () {
    test('chain of Secrets all copy the final regular room', () {
      // first(E) → second(E) → Kitchen
      final first = BeyondThePail(); // E
      final second = WithinTheWalls(); // E
      final kitchen = Kitchen();
      final grid = GridList<Tile>(4, [
        Empty(),
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        Empty(),
        first,
        second,
        kitchen,
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.refreshSecretRoomDuplicates();

      expect(first.duplicate?.id, kitchen.id);
      expect(second.duplicate?.id, kitchen.id);
      expect(first.tileType, TileType.Food);
      expect(second.tileType, TileType.Food);
    });

    test('three-Secret chain copies the same regular room', () {
      final a = BeyondThePail(); // E
      final b = WithinTheWalls(); // E
      final c = AroundTheCorner(); // E
      final kitchen = Kitchen();
      final grid = GridList<Tile>(5, [
        Empty(),
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        Empty(),
        Empty(),
        a,
        b,
        c,
        kitchen,
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.refreshSecretRoomDuplicates();

      expect(a.duplicate?.id, kitchen.id);
      expect(b.duplicate?.id, kitchen.id);
      expect(c.duplicate?.id, kitchen.id);
    });

    test('Secret cycle scores 0 and does not bind', () {
      // A(E) → B(W) → A
      final a = WithinTheWalls(); // E
      final b = BehindTheBookCase(); // W
      final grid = GridList<Tile>(3, [
        Empty(),
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        a,
        b,
        Empty(),
        Empty(),
        Empty(),
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.scoreCastle([]);

      expect(castle.tileScores[a.id], 0);
      expect(castle.tileScores[b.id], 0);
      expect(castle.totalSecret, 2);

      castle.refreshSecretRoomDuplicates();
      expect(a.duplicate, isNull);
      expect(b.duplicate, isNull);
    });
  });

  group('Secrets cannot copy specialty rooms', () {
    test('pointing at Tower scores 0 but placement is fine', () {
      final secret = WithinTheWalls(); // E
      final tower = Tower();
      final grid = GridList<Tile>(3, [
        Empty(),
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        secret,
        tower,
        Empty(),
        Empty(),
        Empty(),
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.scoreCastle([]);

      expect(castle.tileScores[secret.id], 0);
      expect(castle.totalSecret, 1);
      expect(castle.castleScoreCard!.secret[secret.id], 0);

      castle.refreshSecretRoomDuplicates();
      expect(secret.duplicate, isNull);
    });

    test('pointing at ThroneRoom scores 0', () {
      final secret = WithinTheWalls(); // E into throne
      final grid = GridList<Tile>(3, [
        secret,
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        Empty(),
        Empty(),
        Empty(),
        Empty(),
        Empty(),
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.scoreCastle([]);

      expect(castle.tileScores[secret.id], 0);
      expect(castle.totalSecret, 1);
      castle.refreshSecretRoomDuplicates();
      expect(secret.duplicate, isNull);
    });

    test('Secret → Secret → Tower chain scores 0 for both', () {
      final first = BeyondThePail(); // E
      final second = WithinTheWalls(); // E
      final tower = Tower();
      final grid = GridList<Tile>(4, [
        Empty(),
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        Empty(),
        first,
        second,
        tower,
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.scoreCastle([]);

      expect(castle.tileScores[first.id], 0);
      expect(castle.tileScores[second.id], 0);
      expect(castle.totalSecret, 2);
      castle.refreshSecretRoomDuplicates();
      expect(first.duplicate, isNull);
      expect(second.duplicate, isNull);
    });

    test('Fountain and BallRoom are not copyable', () {
      final atFountain = ClimbTheLadder(); // S
      final atBall = WithinTheWalls(); // E
      final fountain = Fountain();
      final ball = BallRoomPerFood();
      final grid = GridList<Tile>(4, [
        Empty(),
        ThroneRoomPerCorridorFood(),
        Placeholder(),
        Empty(),
        atBall,
        ball,
        Empty(),
        Empty(),
        Empty(),
        atFountain,
        Empty(),
        Empty(),
        Empty(),
        fountain,
        Empty(),
        Empty(),
      ]);
      final castle = Castle(grid);
      castle.scoreCastle([]);

      expect(castle.tileScores[atFountain.id], 0);
      expect(castle.tileScores[atBall.id], 0);
      expect(castle.totalSecret, 2);
    });
  });
}
