import 'dart:math';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/tile_placement.dart';

/// Builds a debug starting castle: keeps a fixed footprint, randomizes rooms
/// that obey [TilePlacement] rules (level types, support, outdoor stacking).
class RandomDebugCastle {
  RandomDebugCastle._();

  /// Occupied footprint from the classic debug castle (empties stay empty).
  static GridList<Tile> shapeTemplate() => TileHelper().getTestGridList();

  static GridList<Tile> generate({Random? random, GridList<Tile>? shape}) {
    final rng = random ?? Random();
    final template = shape ?? shapeTemplate();

    // A few retries if a rare edge case still leaves an illegal cell.
    for (var attempt = 0; attempt < 12; attempt++) {
      final grid = _generateOnce(rng, template);
      if (_isFullyValid(grid)) return grid;
    }
    return _generateOnce(rng, template);
  }

  static GridList<Tile> _generateOnce(Random rng, GridList<Tile> template) {
    final w = template.width;
    final helper = TileHelper();

    final thrones = helper.getAllThroneRooms();
    final throne = thrones[rng.nextInt(thrones.length)];

    final items = List<Tile>.generate(template.items.length, (i) {
      final t = template.items[i];
      if (t.isEmpty()) return Empty();
      if (t.isPlaceholder()) return Placeholder();
      if (t.isThroneRoom()) return helper.getTileById(throne.id);
      return Empty();
    });

    final grid = GridList<Tile>(w, items);

    final fillIndices = <int>[];
    for (var i = 0; i < template.items.length; i++) {
      final t = template.items[i];
      if (t.isEmpty() || t.isPlaceholder() || t.isThroneRoom()) continue;
      if (t.isBonusCard() || t.isRoyalAttendant()) continue;
      fillIndices.add(i);
    }

    final ground = TilePlacement.groundRow(grid);
    if (ground == null) return grid;

    fillIndices.sort((a, b) {
      final ya = a ~/ w;
      final yb = b ~/ w;
      final ra = _fillRank(ya, ground);
      final rb = _fillRank(yb, ground);
      if (ra != rb) return ra.compareTo(rb);
      return a.compareTo(b);
    });

    final pool = _roomPool(helper);

    for (final index in fillIndices) {
      final tile = _pickTile(
        rng: rng,
        grid: grid,
        template: template,
        index: index,
        pool: pool,
      );
      if (tile != null) {
        grid.items[index] = tile;
      }
    }

    return grid;
  }

  /// Ground first, then upward floors (near → far), then basements (near → far).
  static int _fillRank(int y, int ground) {
    if (y == ground) return y;
    if (y < ground) return 1000 + (ground - y);
    return 2000 + (y - ground);
  }

  static Tile? _pickTile({
    required Random rng,
    required GridList<Tile> grid,
    required GridList<Tile> template,
    required int index,
    required List<Tile> pool,
  }) {
    final shapeBlocksOutdoor = _shapeHasRoomAboveInColumn(template, index);

    bool usable(Tile tile) {
      if (TilePlacement.isTrueOutdoor(tile) && shapeBlocksOutdoor) {
        return false;
      }
      return TilePlacement.canPlaceTile(
        grid,
        index,
        tile,
        requireSupport: true,
      );
    }

    final candidates = pool.where(usable).toList();
    if (candidates.isNotEmpty) {
      return candidates[rng.nextInt(candidates.length)];
    }

    // Support-safe deterministic fallbacks only — never relax requireSupport.
    for (final tile in _safeFallbacks(grid, index)) {
      if (usable(tile)) return tile;
    }
    return null;
  }

  static List<Tile> _safeFallbacks(GridList<Tile> grid, int index) {
    final level = TilePlacement.levelRelativeToGround(grid, index);
    switch (level) {
      case CastleLevel.below:
        return [Dungeon(), Crypt()];
      case CastleLevel.ground:
      case CastleLevel.above:
        return [GreatHall(), Kitchen(), QuietRoom(), PowderRoom()];
      case null:
        return [GreatHall(), Dungeon()];
    }
  }

  /// True if any shape room sits above [index] in the same column.
  static bool _shapeHasRoomAboveInColumn(GridList<Tile> template, int index) {
    final w = template.width;
    for (var above = index - w; above >= 0; above -= w) {
      final t = template.items[above];
      if (t.isEmpty() || t.isPlaceholder()) continue;
      if (t.isBonusCard() || t.isRoyalAttendant()) continue;
      return true;
    }
    return false;
  }

  static bool _isFullyValid(GridList<Tile> grid) {
    for (var i = 0; i < grid.items.length; i++) {
      if (TilePlacement.invalidReasons(grid, i).isNotEmpty) return false;
    }
    return true;
  }

  /// One instance per tile name (drops Tower2… duplicates).
  static List<Tile> _roomPool(TileHelper helper) {
    final byName = <String, Tile>{};
    for (final tile in helper.listOfAllTiles) {
      if (tile.isEmpty() ||
          tile.isPlaceholder() ||
          tile.isThroneRoom() ||
          tile.isBonusCard() ||
          tile.isRoyalAttendant()) {
        continue;
      }
      byName.putIfAbsent(tile.name, () => tile);
    }
    return byName.values.toList();
  }
}
