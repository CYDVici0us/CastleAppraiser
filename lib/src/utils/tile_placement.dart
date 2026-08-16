import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/grid_expander.dart';

/// Vertical position relative to the throne-room (ground) row.
enum CastleLevel {
  above,
  ground,
  below,
}

/// Why an occupied cell breaks placement rules (camera or edit leftovers).
enum PlacementInvalidReason {
  aboveOutdoor,
  unsupportedAboveGround,
  wrongTypeForLevel,
  /// Empty hole under an upper-floor room or through a run of rooms.
  structuralGap,
}

/// Placement rules for castle grid editing.
class TilePlacement {
  TilePlacement._();

  static bool _isSupportTile(Tile tile) => !tile.isEmpty();

  /// Y index of the throne room row, or null if none.
  static int? groundRow(GridList<Tile> grid) {
    for (int i = 0; i < grid.items.length; i++) {
      if (grid.items[i].tileType == TileType.ThroneRoom) {
        return i ~/ grid.width;
      }
    }
    // Placeholder is the east half of the throne; infer ground from it.
    for (int i = 0; i < grid.items.length; i++) {
      if (grid.items[i].tileType == TileType.Placeholder) {
        return i ~/ grid.width;
      }
    }
    return null;
  }

  static CastleLevel? levelRelativeToGround(GridList<Tile> grid, int index) {
    if (index < 0 || index >= grid.items.length) return null;
    final ground = groundRow(grid);
    if (ground == null) return null;
    final y = index ~/ grid.width;
    if (y < ground) return CastleLevel.above;
    if (y > ground) return CastleLevel.below;
    return CastleLevel.ground;
  }

  /// Occupied cell directly below [index] that can support an upper floor.
  static bool hasSupportBelow(GridList<Tile> grid, int index) {
    if (index < 0 || index >= grid.items.length) return false;
    final below = index + grid.width;
    if (below >= grid.items.length) return false;
    return _isSupportTile(grid.items[below]);
  }

  /// Room / token types allowed at [level].
  static bool isTypeAllowedAtLevel(TileType type, CastleLevel level) {
    switch (type) {
      case TileType.Empty:
      case TileType.Placeholder:
        return true;
      case TileType.ThroneRoom:
        return level == CastleLevel.ground;
      case TileType.Downstairs:
        return level == CastleLevel.below;
      case TileType.Food:
      case TileType.Living:
      case TileType.Utility:
      case TileType.Outdoor:
      case TileType.Sleeping:
      case TileType.Special:
      case TileType.Activity:
        return level == CastleLevel.ground || level == CastleLevel.above;
      case TileType.Corridor:
      case TileType.Secret:
      case TileType.BonusCard:
      case TileType.RoyalAttendant:
        return true;
    }
  }

  /// Placeable categories for the structural castle picker at [level]
  /// (excludes BonusCard / RoyalAttendant — those use the token strip).
  static List<TileType> allowedPickerTypesForLevel(CastleLevel level) {
    return kStructuralPickerTileTypes
        .where((t) => isTypeAllowedAtLevel(t, level))
        .toList();
  }

  /// True when [index] is the cell immediately above an Outdoor tile.
  static bool isDirectlyAboveOutdoor(GridList<Tile> grid, int index) {
    if (index < 0 || index >= grid.items.length) return false;
    final below = index + grid.width;
    if (below >= grid.items.length) return false;
    return grid.items[below].tileType == TileType.Outdoor;
  }

  /// True when placing an Outdoor at [index] would put it under an occupied cell.
  static bool wouldPutOutdoorUnderTile(GridList<Tile> grid, int index) {
    if (index < 0 || index >= grid.items.length) return false;
    final above = index - grid.width;
    if (above < 0) return false;
    return !grid.items[above].isEmpty();
  }

  /// Whether [tile] may be placed at [index].
  ///
  /// [requireSupport] applies to above-ground cells (use false when replacing
  /// an already-occupied camera cell that may be floating).
  /// [allowAboveOutdoor] allows replacing an already-illegal above-Outdoor cell.
  static bool canPlaceTile(
    GridList<Tile> grid,
    int index,
    Tile tile, {
    bool allowAboveOutdoor = false,
    bool requireSupport = true,
  }) {
    if (index < 0 || index >= grid.items.length) return false;
    if (tile.isEmpty() || tile.isPlaceholder()) return false;
    // Bonus / royal attendants belong on the token strip, not the castle map.
    if (tile.isBonusCard() || tile.isRoyalAttendant()) return false;

    if (!allowAboveOutdoor && isDirectlyAboveOutdoor(grid, index)) {
      return false;
    }
    if (tile.tileType == TileType.Outdoor &&
        wouldPutOutdoorUnderTile(grid, index)) {
      return false;
    }

    final level = levelRelativeToGround(grid, index);
    if (level != null && !isTypeAllowedAtLevel(tile.tileType, level)) {
      return false;
    }

    if (requireSupport &&
        level == CastleLevel.above &&
        !hasSupportBelow(grid, index)) {
      return false;
    }

    return true;
  }

  /// Human-readable invalid reasons for a cell (room or empty gap).
  static List<PlacementInvalidReason> invalidReasons(
    GridList<Tile> grid,
    int index,
  ) {
    if (index < 0 || index >= grid.items.length) return const [];
    final tile = grid.items[index];
    if (tile.tileType == TileType.Placeholder) {
      return const [];
    }

    if (tile.isEmpty()) {
      return isInvalidStructuralGap(grid, index)
          ? const [PlacementInvalidReason.structuralGap]
          : const [];
    }

    if (tile.tileType == TileType.ThroneRoom) return const [];

    final reasons = <PlacementInvalidReason>[];
    if (isDirectlyAboveOutdoor(grid, index)) {
      reasons.add(PlacementInvalidReason.aboveOutdoor);
    }

    final level = levelRelativeToGround(grid, index);
    if (level == CastleLevel.above && !hasSupportBelow(grid, index)) {
      reasons.add(PlacementInvalidReason.unsupportedAboveGround);
    }
    if (level != null && !isTypeAllowedAtLevel(tile.tileType, level)) {
      reasons.add(PlacementInvalidReason.wrongTypeForLevel);
    }
    return reasons;
  }

  /// Empty cell that breaks castle structure (support hole or gap in a room run).
  static bool isInvalidStructuralGap(GridList<Tile> grid, int index) {
    if (index < 0 || index >= grid.items.length) return false;
    if (!grid.items[index].isEmpty()) return false;

    final w = grid.width;
    final above = index - w;
    if (above >= 0) {
      final aboveTile = grid.items[above];
      if (!aboveTile.isEmpty() &&
          aboveTile.tileType != TileType.Placeholder &&
          levelRelativeToGround(grid, above) == CastleLevel.above) {
        // Empty under an upper-floor room → missing support.
        return true;
      }
    }

    // Hole in a horizontal or vertical run of rooms.
    final x = index % w;
    final y = index ~/ w;
    bool occ(int nx, int ny) {
      if (nx < 0 || ny < 0 || nx >= w || ny >= grid.height) return false;
      final t = grid.items[nx + ny * w];
      return !t.isEmpty() && t.tileType != TileType.Placeholder;
    }

    final left = occ(x - 1, y);
    final right = occ(x + 1, y);
    final up = occ(x, y - 1);
    final down = occ(x, y + 1);
    if ((left && right) || (up && down)) return true;

    return false;
  }

  static bool hasInvalidPlacement(GridList<Tile> grid, int index) =>
      invalidReasons(grid, index).isNotEmpty;

  /// Occupied cell that sits directly above an Outdoor tile.
  static bool hasInvalidAboveOutdoorPlacement(GridList<Tile> grid, int index) =>
      invalidReasons(grid, index)
          .contains(PlacementInvalidReason.aboveOutdoor);

  static String describeInvalidReason(PlacementInvalidReason reason) {
    switch (reason) {
      case PlacementInvalidReason.aboveOutdoor:
        return 'Cannot sit above Outdoor';
      case PlacementInvalidReason.unsupportedAboveGround:
        return 'Needs a tile below for support';
      case PlacementInvalidReason.wrongTypeForLevel:
        return 'Wrong room type for this floor';
      case PlacementInvalidReason.structuralGap:
        return 'Invalid gap — fill or close this hole';
    }
  }

  static bool isSameRow(GridList<Tile> grid, int a, int b) =>
      a ~/ grid.width == b ~/ grid.width;

  static bool isSameColumn(GridList<Tile> grid, int a, int b) =>
      a % grid.width == b % grid.width;

  static bool isOrthogonal(GridList<Tile> grid, int a, int b) =>
      isSameRow(grid, a, b) || isSameColumn(grid, a, b);

  static bool isDiagonal(GridList<Tile> grid, int a, int b) =>
      !isSameRow(grid, a, b) && !isSameColumn(grid, a, b);

  static bool _isImmovable(Tile tile) =>
      tile.tileType == TileType.ThroneRoom ||
      tile.tileType == TileType.Placeholder;

  /// Whether a gap-closing segment rotate from [sourceIndex] to [destIndex] is allowed.
  /// [sourceIndex] is the vacated cell (already empty during an in-progress drag).
  static bool canRotateSegment(
    GridList<Tile> grid,
    int sourceIndex,
    int destIndex,
  ) {
    if (sourceIndex == destIndex) return false;
    if (sourceIndex < 0 ||
        destIndex < 0 ||
        sourceIndex >= grid.items.length ||
        destIndex >= grid.items.length) {
      return false;
    }
    if (!isOrthogonal(grid, sourceIndex, destIndex)) return false;
    if (_isImmovable(grid.items[destIndex])) return false;
    // Never slide through the ground row — that pushes ground tiles below
    // (or downstairs above) and creates invalid floors.
    if (_crossesCastleLevel(grid, sourceIndex, destIndex)) return false;

    final step = isSameRow(grid, sourceIndex, destIndex)
        ? 1
        : grid.width;
    final from = sourceIndex < destIndex ? sourceIndex : destIndex;
    final to = sourceIndex < destIndex ? destIndex : sourceIndex;
    for (int i = from; i <= to; i += step) {
      if (i == sourceIndex) continue;
      if (_isImmovable(grid.items[i])) return false;
    }
    return true;
  }

  /// True when source and dest sit on different sides of ground (above / ground / below).
  static bool _crossesCastleLevel(
    GridList<Tile> grid,
    int sourceIndex,
    int destIndex,
  ) {
    final a = levelRelativeToGround(grid, sourceIndex);
    final b = levelRelativeToGround(grid, destIndex);
    if (a == null || b == null) return false;
    return a != b;
  }

  /// Rotates the orthogonal segment so [tile] lands at [destIndex] and neighbors
  /// slide toward [sourceIndex] to close the gap.
  ///
  /// Mutates [grid.items] in place. Returns false if the rotate is not allowed.
  static bool rotateSegment(
    GridList<Tile> grid,
    int sourceIndex,
    int destIndex,
    Tile tile,
  ) {
    if (!canRotateSegment(grid, sourceIndex, destIndex)) return false;

    final step = isSameRow(grid, sourceIndex, destIndex) ? 1 : grid.width;

    if (sourceIndex < destIndex) {
      // Moving toward higher indices: shift toward the gap (lower indices).
      for (int i = sourceIndex; i < destIndex; i += step) {
        grid.items[i] = grid.items[i + step];
      }
    } else {
      // Moving toward lower indices: shift toward the gap (higher indices).
      for (int i = sourceIndex; i > destIndex; i -= step) {
        grid.items[i] = grid.items[i - step];
      }
    }
    grid.items[destIndex] = tile;
    return true;
  }

  /// Closes empty holes by packing movable tiles toward the throne/ground.
  ///
  /// Above ground: tiles fall down toward the ground row.
  /// Below ground: tiles rise up toward the ground row.
  /// Then each non-ground row packs horizontally toward the throne column.
  /// Throne/placeholder cells never move. Invalid leftovers are left for badges.
  static void compactTowardGround(
    GridList<Tile> grid, {
    required Tile Function() getEmpty,
  }) {
    final ground = groundRow(grid);
    if (ground == null) return;

    final w = grid.width;
    final h = grid.height;
    int throneX = 0;
    for (int i = 0; i < grid.items.length; i++) {
      if (grid.items[i].tileType == TileType.ThroneRoom) {
        throneX = i % w;
        break;
      }
    }

    for (int x = 0; x < w; x++) {
      _compactColumnTowardGround(grid, x, ground, getEmpty);
    }
    // Include ground row so bonuses removed beside the throne close sideways.
    for (int y = 0; y < h; y++) {
      _compactRowTowardThrone(grid, y, throneX, getEmpty);
    }
  }

  static void _compactColumnTowardGround(
    GridList<Tile> grid,
    int x,
    int ground,
    Tile Function() getEmpty,
  ) {
    final w = grid.width;
    final h = grid.height;

    // Above ground: pack downward against the ground row.
    final above = <Tile>[];
    final lockedAbove = <int, Tile>{};
    for (int y = 0; y < ground && y < h; y++) {
      final t = grid.items[y * w + x];
      if (_isImmovable(t)) {
        lockedAbove[y] = t;
      } else if (!t.isEmpty()) {
        above.add(t);
      }
    }
    for (int y = 0; y < ground && y < h; y++) {
      if (!lockedAbove.containsKey(y)) {
        grid.items[y * w + x] = getEmpty();
      }
    }
    var placeY = ground - 1;
    for (int i = above.length - 1; i >= 0; i--) {
      while (placeY >= 0 && lockedAbove.containsKey(placeY)) {
        placeY--;
      }
      if (placeY < 0) break;
      grid.items[placeY * w + x] = above[i];
      placeY--;
    }

    // Below ground: pack upward against the ground row.
    final below = <Tile>[];
    final lockedBelow = <int, Tile>{};
    for (int y = ground + 1; y < h; y++) {
      final t = grid.items[y * w + x];
      if (_isImmovable(t)) {
        lockedBelow[y] = t;
      } else if (!t.isEmpty()) {
        below.add(t);
      }
    }
    for (int y = ground + 1; y < h; y++) {
      if (!lockedBelow.containsKey(y)) {
        grid.items[y * w + x] = getEmpty();
      }
    }
    placeY = ground + 1;
    for (final tile in below) {
      while (placeY < h && lockedBelow.containsKey(placeY)) {
        placeY++;
      }
      if (placeY >= h) break;
      grid.items[placeY * w + x] = tile;
      placeY++;
    }
  }

  static void _compactRowTowardThrone(
    GridList<Tile> grid,
    int y,
    int throneX,
    Tile Function() getEmpty,
  ) {
    final w = grid.width;
    final left = <Tile>[];
    final right = <Tile>[];
    final locked = <int, Tile>{};
    Tile? atThroneCol;

    for (int x = 0; x < w; x++) {
      final t = grid.items[y * w + x];
      if (_isImmovable(t)) {
        locked[x] = t;
      } else if (!t.isEmpty()) {
        if (x < throneX) {
          left.add(t);
        } else if (x > throneX) {
          right.add(t);
        } else {
          atThroneCol = t;
        }
      }
    }

    for (int x = 0; x < w; x++) {
      if (!locked.containsKey(x)) {
        grid.items[y * w + x] = getEmpty();
      }
    }

    if (atThroneCol != null && !locked.containsKey(throneX)) {
      grid.items[y * w + throneX] = atThroneCol;
    }

    var placeX = throneX - 1;
    for (int i = left.length - 1; i >= 0; i--) {
      while (placeX >= 0 && locked.containsKey(placeX)) {
        placeX--;
      }
      if (placeX < 0) break;
      grid.items[y * w + placeX] = left[i];
      placeX--;
    }

    placeX = throneX + 1;
    for (final tile in right) {
      while (placeX < w && locked.containsKey(placeX)) {
        placeX++;
      }
      if (placeX >= w) break;
      grid.items[y * w + placeX] = tile;
      placeX++;
    }
  }

  /// Orthogonal move: prefer segment rotate; if blocked (e.g. throne in the
  /// way), allow relocating into an empty legal cell so wrong-floor tiles can
  /// cross the ground row. Caller should [compactTowardGround] after a
  /// non-rotate relocate.
  static bool canOrthogonallyRelocate(
    GridList<Tile> grid,
    int sourceIndex,
    int destIndex,
    Tile tile, {
    required bool Function(int index) canAddAt,
    required bool Function(int index, Tile tile) canPlaceTile,
  }) {
    if (sourceIndex == destIndex) return false;
    if (!isOrthogonal(grid, sourceIndex, destIndex)) return false;
    if (canRotateSegment(grid, sourceIndex, destIndex)) return true;
    final dest = grid.items[destIndex];
    if (!dest.isEmpty()) return false;
    return canAddAt(destIndex) && canPlaceTile(destIndex, tile);
  }

  /// Performs an orthogonal relocate. Returns [OrthogonalMoveResult.rotated]
  /// if segment rotate was used, [OrthogonalMoveResult.relocated] if the tile
  /// was placed and the source hole should be compacted, or failed.
  static OrthogonalMoveResult tryOrthogonallyRelocate(
    GridList<Tile> grid,
    int sourceIndex,
    int destIndex,
    Tile tile, {
    required bool Function(int index) canAddAt,
    required bool Function(int index, Tile tile) canPlaceTile,
  }) {
    if (!canOrthogonallyRelocate(
      grid,
      sourceIndex,
      destIndex,
      tile,
      canAddAt: canAddAt,
      canPlaceTile: canPlaceTile,
    )) {
      return OrthogonalMoveResult.failed;
    }
    if (canRotateSegment(grid, sourceIndex, destIndex)) {
      rotateSegment(grid, sourceIndex, destIndex, tile);
      return OrthogonalMoveResult.rotated;
    }
    grid.items[destIndex] = tile;
    return OrthogonalMoveResult.relocated;
  }
}

/// Result of [TilePlacement.tryOrthogonallyRelocate].
enum OrthogonalMoveResult {
  failed,
  rotated,
  relocated,
}

/// All placeable categories including token strip types.
const List<TileType> kAllPickerTileTypes = [
  TileType.Corridor,
  TileType.Downstairs,
  TileType.Food,
  TileType.Living,
  TileType.Outdoor,
  TileType.Sleeping,
  TileType.Special,
  TileType.Utility,
  TileType.Activity,
  TileType.Secret,
  TileType.RoyalAttendant,
  TileType.BonusCard,
];

/// Structural castle picker categories (rooms only).
const List<TileType> kStructuralPickerTileTypes = [
  TileType.Corridor,
  TileType.Downstairs,
  TileType.Food,
  TileType.Living,
  TileType.Outdoor,
  TileType.Sleeping,
  TileType.Special,
  TileType.Utility,
  TileType.Activity,
  TileType.Secret,
];
