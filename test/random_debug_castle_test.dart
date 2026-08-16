import 'dart:math';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/random_debug_castle.dart';
import 'package:btcc/src/utils/tile_placement.dart';
import 'package:test/test.dart';

void main() {
  group('RandomDebugCastle', () {
    test('keeps the template footprint', () {
      final shape = RandomDebugCastle.shapeTemplate();
      final grid = RandomDebugCastle.generate(random: Random(1));

      expect(grid.width, shape.width);
      expect(grid.items.length, shape.items.length);

      for (var i = 0; i < shape.items.length; i++) {
        final s = shape.items[i];
        final g = grid.items[i];
        if (s.isEmpty()) {
          expect(g.isEmpty(), isTrue, reason: 'index $i should stay empty');
        } else if (s.isPlaceholder()) {
          expect(g.isPlaceholder(), isTrue);
        } else if (s.isThroneRoom()) {
          expect(g.isThroneRoom(), isTrue);
        } else {
          expect(g.isEmpty(), isFalse, reason: 'index $i should be filled');
          expect(g.isPlaceholder(), isFalse);
          expect(g.isThroneRoom(), isFalse);
        }
      }
    });

    test('generated castles follow placement rules', () {
      for (var seed = 0; seed < 100; seed++) {
        final grid = RandomDebugCastle.generate(random: Random(seed));
        for (var i = 0; i < grid.items.length; i++) {
          final reasons = TilePlacement.invalidReasons(grid, i);
          expect(
            reasons,
            isEmpty,
            reason: 'seed $seed index $i: $reasons '
                '(${grid.items[i].name})',
          );
        }
      }
    });

    test('never leaves floating rooms above empties', () {
      for (var seed = 0; seed < 100; seed++) {
        final grid = RandomDebugCastle.generate(random: Random(seed));
        final w = grid.width;
        for (var i = 0; i < grid.items.length; i++) {
          final tile = grid.items[i];
          if (tile.isEmpty() ||
              tile.isPlaceholder() ||
              tile.isThroneRoom() ||
              tile.isBonusCard() ||
              tile.isRoyalAttendant()) {
            continue;
          }
          final level = TilePlacement.levelRelativeToGround(grid, i);
          if (level == CastleLevel.above) {
            expect(
              TilePlacement.hasSupportBelow(grid, i),
              isTrue,
              reason: 'seed $seed floating ${tile.name} at $i',
            );
          }
          if (level == CastleLevel.below) {
            expect(
              TilePlacement.hasSupportAbove(grid, i),
              isTrue,
              reason: 'seed $seed floating basement ${tile.name} at $i',
            );
          }
          // No Outdoor / Tower / Fountain under a room in this column.
          if (TilePlacement.blocksRoomsAbove(tile)) {
            final above = i - w;
            if (above >= 0) {
              expect(
                grid.items[above].isEmpty() ||
                    grid.items[above].isPlaceholder(),
                isTrue,
                reason:
                    'seed $seed ${tile.name} under room at $above',
              );
            }
          }
        }
      }
    });

    test('different seeds yield different layouts', () {
      final a = RandomDebugCastle.generate(random: Random(7));
      final b = RandomDebugCastle.generate(random: Random(99));
      final aIds = a.items.map((t) => t.id).toList();
      final bIds = b.items.map((t) => t.id).toList();
      expect(aIds, isNot(equals(bIds)));
    });
  });
}
