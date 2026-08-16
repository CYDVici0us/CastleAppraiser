import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/widgets/tile/scoring_blurb.dart';
import 'package:btcc/src/widgets/tile/scoring_placement_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScoringPlacementMapping.throneCells', () {
    test('N+NE lights two top cells above throne', () {
      final cells = ScoringPlacementMapping.throneCells([
        ScoringPosition.N,
        ScoringPosition.NE,
      ]);
      expect(cells[1], PlacementCellKind.scoring); // (1,2)
      expect(cells[2], PlacementCellKind.scoring); // (1,3)
      expect(cells[5], PlacementCellKind.self);
      expect(cells[6], PlacementCellKind.self);
      expect(cells.where((c) => c == PlacementCellKind.scoring).length, 2);
    });

    test('W+EE lights both side cells', () {
      final cells = ScoringPlacementMapping.throneCells([
        ScoringPosition.W,
        ScoringPosition.EE,
      ]);
      expect(cells[4], PlacementCellKind.scoring); // (2,1)
      expect(cells[7], PlacementCellKind.scoring); // (2,4)
      expect(cells[5], PlacementCellKind.self);
      expect(cells[6], PlacementCellKind.self);
    });

    test('S+SE lights two bottom cells under throne', () {
      final cells = ScoringPlacementMapping.throneCells([
        ScoringPosition.S,
        ScoringPosition.SE,
      ]);
      expect(cells[9], PlacementCellKind.scoring); // (3,2)
      expect(cells[10], PlacementCellKind.scoring); // (3,3)
      expect(cells[5], PlacementCellKind.self);
      expect(cells[6], PlacementCellKind.self);
    });

    test('E and SS do not paint cells', () {
      final cells = ScoringPlacementMapping.throneCells([
        ScoringPosition.E,
        ScoringPosition.SS,
      ]);
      expect(cells.where((c) => c == PlacementCellKind.scoring), isEmpty);
      expect(cells[5], PlacementCellKind.self);
      expect(cells[6], PlacementCellKind.self);
    });
  });

  group('ScoringPlacementMapping.standardCells', () {
    test('single N lights north neighbor', () {
      final cells = ScoringPlacementMapping.standardCells([ScoringPosition.N]);
      expect(cells[4], PlacementCellKind.self);
      expect(cells[1], PlacementCellKind.scoring);
      expect(cells.where((c) => c == PlacementCellKind.scoring).length, 1);
    });

    test('Above-only is white self with up arrow, no black cells', () {
      final cells =
          ScoringPlacementMapping.standardCells([ScoringPosition.Above]);
      expect(cells[4], PlacementCellKind.self);
      expect(cells.where((c) => c == PlacementCellKind.scoring), isEmpty);
      expect(ScoringPlacementMapping.verticalArrow([ScoringPosition.Above]),
          PlacementArrow.up);
    });

    test('Below-only is white self with down arrow, no black cells', () {
      final cells =
          ScoringPlacementMapping.standardCells([ScoringPosition.Below]);
      expect(cells[4], PlacementCellKind.self);
      expect(cells.where((c) => c == PlacementCellKind.scoring), isEmpty);
      expect(ScoringPlacementMapping.verticalArrow([ScoringPosition.Below]),
          PlacementArrow.down);
    });
  });

  group('ScoringPlacementMapping.secretArrow', () {
    test('maps single cardinal to arrow-only direction', () {
      expect(ScoringPlacementMapping.secretArrow([ScoringPosition.N]),
          PlacementArrow.up);
      expect(ScoringPlacementMapping.secretArrow([ScoringPosition.E]),
          PlacementArrow.right);
      expect(ScoringPlacementMapping.secretArrow([ScoringPosition.S]),
          PlacementArrow.down);
      expect(ScoringPlacementMapping.secretArrow([ScoringPosition.W]),
          PlacementArrow.left);
    });

    test('shows for secret tiles', () {
      expect(ScoringPlacementMapping.shouldShow(RideTheDumbWaiter()), isTrue);
    });

    test('keeps printed arrow when scoring duplicate is set', () {
      final secret = ClimbTheLadder()
        ..duplicate = ArtSupplies(); // Connected Outdoor utility
      expect(secret.isSecret(), isTrue);
      expect(ScoringPlacementMapping.shouldShow(secret), isTrue);
      expect(
        ScoringPlacementMapping.secretArrow(secret.baseScoringPositions),
        PlacementArrow.down,
      );
      expect(ScoringBlurb.hasContent(secret), isFalse);
      final grid = ScoringPlacementGrid.forTile(secret);
      expect(grid.arrowOnly, isTrue);
      expect(grid.arrow, PlacementArrow.down);
    });
  });

  group('ScoringPlacementMapping.shouldShow', () {
    test('hides Type-scoped tiles', () {
      expect(
        ScoringPlacementMapping.shouldShow(
          Tile(
            name: 'Type Scope',
            id: TileId.Kitchen,
            tileType: TileType.Food,
            decorationType: DecorationType.None,
            scorePer: 1,
            scoringCondition: ScoringCondition.Food,
            scoringPositions: const [ScoringPosition.Type],
          ),
        ),
        isFalse,
      );
    });

    test('shows ordinal neighbor sets', () {
      expect(ScoringPlacementMapping.shouldShow(Kitchen()), isTrue);
    });

    test('shows Activity with dual diagrams', () {
      expect(ScoringPlacementMapping.shouldShow(EscapeRoomActivity()), isTrue);
      expect(
        ScoringPlacementMapping.activityCardinalPositions,
        [
          ScoringPosition.N,
          ScoringPosition.E,
          ScoringPosition.S,
          ScoringPosition.W,
        ],
      );
      expect(
        ScoringPlacementMapping.activitySurroundingPositions.length,
        8,
      );
      final cardinal = ScoringPlacementMapping.standardCells(
        ScoringPlacementMapping.activityCardinalPositions,
      );
      expect(cardinal.where((c) => c == PlacementCellKind.scoring).length, 4);
      final surround = ScoringPlacementMapping.standardCells(
        ScoringPlacementMapping.activitySurroundingPositions,
      );
      expect(surround.where((c) => c == PlacementCellKind.scoring).length, 8);
    });
  });

  group('ScoringBlurb activity', () {
    test('lists adjacency before specialty override', () {
      final tile = EscapeRoomActivity();
      expect(ScoringBlurb.hasContent(tile), isTrue);
      final runs = ScoringBlurb.runsTextFor(tile);
      expect(runs.first, contains('per room'));
      expect(runs.any((r) => r.contains('+1 if ')), isTrue);
      expect(runs.any((r) => r.contains('Utility')), isTrue);
      expect(runs.indexWhere((r) => r.contains('per room')),
          lessThan(runs.indexWhere((r) => r.contains('Utility'))));
    });
  });

  group('Sleeping score details', () {
    test('blurb lists official 7 types with Downstairs after Activity', () {
      final tile = PuppyRoom();
      expect(ScoringBlurb.hasContent(tile), isTrue);
      final text = ScoringBlurb.runsTextFor(tile).join();
      expect(
        text,
        contains(
          '+4 if ≥6 of Food, Living, Utility, Outdoor, Corridor, Activity, Downstairs',
        ),
      );
      expect(text, contains('+1 otherwise (Sleeping does not count)'));
      expect(text.toLowerCase(), isNot(contains('per sleeping')));
      final activityAt = text.indexOf('Activity');
      final downstairsAt = text.indexOf('Downstairs');
      expect(activityAt, greaterThan(-1));
      expect(downstairsAt, greaterThan(activityAt));
    });

    test('shows regular types diagram', () {
      expect(ScoringPlacementMapping.shouldShow(PuppyRoom()), isTrue);
    });
  });
}

