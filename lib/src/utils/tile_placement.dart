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
  /// Room sits above Outdoor, Tower, or Fountain (nothing may stack there).
  aboveOutdoor,
  unsupportedAboveGround,
  /// Below-ground room with no tile directly above (floating basement).
  unsupportedBelowGround,
  wrongTypeForLevel,
  /// Empty hole under an upper-floor room or through a run of rooms.
  structuralGap,
}

/// Placement rules for castle grid editing.
class TilePlacement {
  TilePlacement._();

  static bool _isSupportTile(Tile tile) =>
      !tile.isEmpty() && !_isVisualToken(tile);

  /// Bonus / royal attendants — scored tokens, not structural rooms.
  /// In view/scoring they sit in a visual row above the castle; nothing
  /// needs to be below them and they must not create placement errors.
  static bool _isVisualToken(Tile tile) =>
      tile.isBonusCard() || tile.isRoyalAttendant();

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

  /// Occupied cell directly above [index] that anchors a below-ground room.
  static bool hasSupportAbove(GridList<Tile> grid, int index) {
    if (index < 0 || index >= grid.items.length) return false;
    final above = index - grid.width;
    if (above < 0) return false;
    return _isSupportTile(grid.items[above]);
  }

  /// Whether an empty cell may receive a newly added room.
  ///
  /// Requires ortho adjacency (or an interior hole), blocks above Outdoor /
  /// Tower / Fountain, blocks above-ground cells with no support below, and
  /// blocks below-ground cells with no support above — so floating
  /// floors/basements cannot start from the add/search UI.
  static bool canAddAtEmptyCell(
    GridList<Tile> grid,
    int index, {
    required bool Function(Tile) isOccupied,
  }) {
    if (index < 0 || index >= grid.items.length) return false;
    if (!grid.items[index].isEmpty()) return false;
    if (isDirectlyAboveNoStackRoom(grid, index)) return false;

    final level = levelRelativeToGround(grid, index);
    if (level == CastleLevel.above && !hasSupportBelow(grid, index)) {
      return false;
    }
    if (level == CastleLevel.below && !hasSupportAbove(grid, index)) {
      return false;
    }

    if (GridListNormalizer.canPlaceAdjacent(
      grid,
      index,
      isOccupied: isOccupied,
    )) {
      return true;
    }
    return GridListNormalizer.isEmptyInsideOccupiedBounds(
      grid,
      index,
      isOccupied: isOccupied,
    );
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

  /// True Outdoor rooms block stacking above them. Secrets that copy an
  /// Outdoor for scoring still use [Tile.tileType] == Outdoor via [Tile.duplicate],
  /// but [Tile.trueTileType] stays Secret — those may have rooms above.
  static bool isTrueOutdoor(Tile tile) =>
      tile.trueTileType == TileType.Outdoor;

  /// True Tower / Fountain specials (all print variants). Secrets that copy
  /// them keep a different [Tile.name] / id — those may have rooms above.
  static bool isTrueTowerOrFountain(Tile tile) =>
      tile.name == 'Tower' || tile.name == 'Fountain';

  /// Rooms that may not have any tile stacked above them.
  static bool blocksRoomsAbove(Tile tile) =>
      isTrueOutdoor(tile) || isTrueTowerOrFountain(tile);

  /// True when [index] is the cell immediately above a no-stack room.
  static bool isDirectlyAboveNoStackRoom(GridList<Tile> grid, int index) {
    if (index < 0 || index >= grid.items.length) return false;
    final below = index + grid.width;
    if (below >= grid.items.length) return false;
    return blocksRoomsAbove(grid.items[below]);
  }

  /// Alias for [isDirectlyAboveNoStackRoom] (historical Outdoor-only name).
  static bool isDirectlyAboveOutdoor(GridList<Tile> grid, int index) =>
      isDirectlyAboveNoStackRoom(grid, index);

  /// True when placing a no-stack room at [index] would put it under an occupied cell.
  static bool wouldPutNoStackRoomUnderTile(GridList<Tile> grid, int index) {
    if (index < 0 || index >= grid.items.length) return false;
    final above = index - grid.width;
    if (above < 0) return false;
    return !grid.items[above].isEmpty();
  }

  /// Alias for [wouldPutNoStackRoomUnderTile].
  static bool wouldPutOutdoorUnderTile(GridList<Tile> grid, int index) =>
      wouldPutNoStackRoomUnderTile(grid, index);

  /// Whether [tile] may be placed at [index].
  ///
  /// [requireSupport] applies to above-ground (needs tile below) and
  /// below-ground (needs tile above). Use false when replacing an already
  /// illegal camera cell that may be floating.
  /// [allowAboveOutdoor] allows replacing an already-illegal cell above a
  /// no-stack room (Outdoor / Tower / Fountain).
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

    if (!allowAboveOutdoor && isDirectlyAboveNoStackRoom(grid, index)) {
      return false;
    }
    if (blocksRoomsAbove(tile) && wouldPutNoStackRoomUnderTile(grid, index)) {
      return false;
    }

    final level = levelRelativeToGround(grid, index);
    if (level != null && !isTypeAllowedAtLevel(tile.trueTileType, level)) {
      return false;
    }

    if (requireSupport) {
      if (level == CastleLevel.above && !hasSupportBelow(grid, index)) {
        return false;
      }
      if (level == CastleLevel.below && !hasSupportAbove(grid, index)) {
        return false;
      }
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
    // Visual-only scoring tokens (bonus / royal attendant row).
    if (_isVisualToken(tile)) return const [];

    if (tile.isEmpty()) {
      return isInvalidStructuralGap(grid, index)
          ? const [PlacementInvalidReason.structuralGap]
          : const [];
    }

    if (tile.tileType == TileType.ThroneRoom) return const [];

    final reasons = <PlacementInvalidReason>[];
    if (isDirectlyAboveNoStackRoom(grid, index)) {
      reasons.add(PlacementInvalidReason.aboveOutdoor);
    }

    final level = levelRelativeToGround(grid, index);
    if (level == CastleLevel.above && !hasSupportBelow(grid, index)) {
      reasons.add(PlacementInvalidReason.unsupportedAboveGround);
    }
    if (level == CastleLevel.below && !hasSupportAbove(grid, index)) {
      reasons.add(PlacementInvalidReason.unsupportedBelowGround);
    }
    if (level != null && !isTypeAllowedAtLevel(tile.trueTileType, level)) {
      reasons.add(PlacementInvalidReason.wrongTypeForLevel);
    }
    return reasons;
  }

  /// Empty cell that breaks castle structure.
  ///
  /// - Missing support under an upper-floor room, or above a below-ground room
  /// - Horizontal holes on the **ground** row only (above/below may have gaps)
  /// Empty cells directly above Outdoor / Tower / Fountain are never gaps
  /// (unbuildable by rule).
  static bool isInvalidStructuralGap(GridList<Tile> grid, int index) {
    if (index < 0 || index >= grid.items.length) return false;
    if (!grid.items[index].isEmpty()) return false;

    // Intentionally empty — nothing may be built above these rooms.
    if (isDirectlyAboveNoStackRoom(grid, index)) return false;

    final w = grid.width;
    final above = index - w;
    if (above >= 0) {
      final aboveTile = grid.items[above];
      // Tokens sit in a visual row; empty cells under them are not gaps.
      if (!aboveTile.isEmpty() &&
          aboveTile.tileType != TileType.Placeholder &&
          !_isVisualToken(aboveTile) &&
          levelRelativeToGround(grid, above) == CastleLevel.above) {
        // Empty under an upper-floor room → missing support.
        return true;
      }
    }

    final below = index + w;
    if (below < grid.items.length) {
      final belowTile = grid.items[below];
      if (!belowTile.isEmpty() &&
          belowTile.tileType != TileType.Placeholder &&
          !_isVisualToken(belowTile) &&
          levelRelativeToGround(grid, below) == CastleLevel.below) {
        // Empty above a below-ground room → floating basement.
        return true;
      }
    }

    // Ground floor only: no horizontal gaps between rooms.
    if (levelRelativeToGround(grid, index) == CastleLevel.ground) {
      final x = index % w;
      final y = index ~/ w;
      bool occ(int nx, int ny) {
        if (nx < 0 || ny < 0 || nx >= w || ny >= grid.height) return false;
        final t = grid.items[nx + ny * w];
        return !t.isEmpty() &&
            t.tileType != TileType.Placeholder &&
            !_isVisualToken(t);
      }

      if (occ(x - 1, y) && occ(x + 1, y)) return true;
    }

    return false;
  }

  static bool hasInvalidPlacement(GridList<Tile> grid, int index) =>
      invalidReasons(grid, index).isNotEmpty;

  /// Occupied cell that sits directly above Outdoor / Tower / Fountain.
  static bool hasInvalidAboveOutdoorPlacement(GridList<Tile> grid, int index) =>
      invalidReasons(grid, index)
          .contains(PlacementInvalidReason.aboveOutdoor);

  static String describeInvalidReason(PlacementInvalidReason reason) {
    switch (reason) {
      case PlacementInvalidReason.aboveOutdoor:
        return 'Cannot sit above Outdoor, Tower, or Fountain';
      case PlacementInvalidReason.unsupportedAboveGround:
        return 'Needs a tile below for support';
      case PlacementInvalidReason.unsupportedBelowGround:
        return 'Needs a tile above for support';
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

  /// Corridor / Secret may sit on any floor, so they can insert-push across
  /// ground from any source level (throne/placeholder never move).
  static bool _isLevelFlexible(TileType type) =>
      type == TileType.Corridor || type == TileType.Secret;

  /// Geometry for inserting at [destIndex] while pushing that column upward.
  ///
  /// Restricted tiles: only from below onto ground/above.
  /// Corridor/Secret ([movingTile]): any upward move in the column.
  static bool canInsertPushUpward(
    GridList<Tile> grid,
    int sourceIndex,
    int destIndex, {
    Tile? movingTile,
  }) {
    if (sourceIndex == destIndex) return false;
    if (sourceIndex < 0 ||
        destIndex < 0 ||
        sourceIndex >= grid.items.length ||
        destIndex >= grid.items.length) {
      return false;
    }
    if (!isSameColumn(grid, sourceIndex, destIndex)) return false;
    if (sourceIndex <= destIndex) return false; // must move upward
    if (_isImmovable(grid.items[destIndex])) return false;

    final step = grid.width;
    for (int i = destIndex - step; i >= 0; i -= step) {
      if (_isImmovable(grid.items[i])) return false;
    }

    if (movingTile != null && _isLevelFlexible(movingTile.tileType)) {
      return true;
    }

    final sourceLevel = levelRelativeToGround(grid, sourceIndex);
    final destLevel = levelRelativeToGround(grid, destIndex);
    if (sourceLevel != CastleLevel.below) return false;
    if (destLevel != CastleLevel.ground && destLevel != CastleLevel.above) {
      return false;
    }
    return true;
  }

  /// Geometry for inserting at [destIndex] while pushing that column downward.
  ///
  /// Restricted tiles: only from above onto ground/below.
  /// Corridor/Secret ([movingTile]): any downward move in the column.
  static bool canInsertPushDownward(
    GridList<Tile> grid,
    int sourceIndex,
    int destIndex, {
    Tile? movingTile,
  }) {
    if (sourceIndex == destIndex) return false;
    if (sourceIndex < 0 ||
        destIndex < 0 ||
        sourceIndex >= grid.items.length ||
        destIndex >= grid.items.length) {
      return false;
    }
    if (!isSameColumn(grid, sourceIndex, destIndex)) return false;
    if (sourceIndex >= destIndex) return false; // must move downward
    if (_isImmovable(grid.items[destIndex])) return false;

    final step = grid.width;
    for (int i = destIndex + step; i < grid.items.length; i += step) {
      if (_isImmovable(grid.items[i])) return false;
    }

    if (movingTile != null && _isLevelFlexible(movingTile.tileType)) {
      return true;
    }

    final sourceLevel = levelRelativeToGround(grid, sourceIndex);
    final destLevel = levelRelativeToGround(grid, destIndex);
    if (sourceLevel != CastleLevel.above) return false;
    if (destLevel != CastleLevel.ground && destLevel != CastleLevel.below) {
      return false;
    }
    return true;
  }

  static bool canInsertPushAcrossGround(
    GridList<Tile> grid,
    int sourceIndex,
    int destIndex, {
    Tile? movingTile,
  }) =>
      canInsertPushUpward(
        grid,
        sourceIndex,
        destIndex,
        movingTile: movingTile,
      ) ||
      canInsertPushDownward(
        grid,
        sourceIndex,
        destIndex,
        movingTile: movingTile,
      );

  /// Inserts [tile] at [destIndex], shifting movable tiles in that column up
  /// (toward lower indices). Prepends an empty row when the column is full.
  /// Throne/placeholder cells are never moved.
  ///
  /// Mutates [grid.items] in place. Returns false if not allowed.
  static bool insertPushUpward(
    GridList<Tile> grid,
    int sourceIndex,
    int destIndex,
    Tile tile, {
    required Tile Function() getEmpty,
  }) {
    if (!canInsertPushUpward(
      grid,
      sourceIndex,
      destIndex,
      movingTile: tile,
    )) {
      return false;
    }

    var dest = destIndex;
    final step = grid.width;
    int? hole;
    for (int i = dest - step; i >= 0; i -= step) {
      if (grid.items[i].isEmpty()) {
        hole = i;
        break;
      }
    }

    if (hole == null) {
      final w = grid.width;
      grid.items.insertAll(0, List<Tile>.generate(w, (_) => getEmpty()));
      dest += w;
      hole = dest % w; // top cell of this column
    }

    for (int i = hole; i < dest; i += step) {
      grid.items[i] = grid.items[i + step];
    }
    grid.items[dest] = tile;
    return true;
  }

  /// Inserts [tile] at [destIndex], shifting movable tiles in that column down
  /// (toward higher indices). Appends an empty row when the column is full.
  /// Throne/placeholder cells are never moved.
  static bool insertPushDownward(
    GridList<Tile> grid,
    int sourceIndex,
    int destIndex,
    Tile tile, {
    required Tile Function() getEmpty,
  }) {
    if (!canInsertPushDownward(
      grid,
      sourceIndex,
      destIndex,
      movingTile: tile,
    )) {
      return false;
    }

    final dest = destIndex;
    final step = grid.width;
    final w = grid.width;
    int? hole;
    for (int i = dest + step; i < grid.items.length; i += step) {
      if (grid.items[i].isEmpty()) {
        hole = i;
        break;
      }
    }

    if (hole == null) {
      grid.items.addAll(List<Tile>.generate(w, (_) => getEmpty()));
      hole = (grid.height - 1) * w + (dest % w);
    }

    for (int i = hole; i > dest; i -= step) {
      grid.items[i] = grid.items[i - step];
    }
    grid.items[dest] = tile;
    return true;
  }

  /// Orthogonal move: prefer segment rotate; else cross-ground insert+push;
  /// else relocate into an empty legal cell. Caller should
  /// [compactTowardGround] after [OrthogonalMoveResult.relocated] or
  /// [OrthogonalMoveResult.pushed].
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
    if (canInsertPushAcrossGround(
          grid,
          sourceIndex,
          destIndex,
          movingTile: tile,
        ) &&
        canPlaceTile(destIndex, tile)) {
      return true;
    }
    final dest = grid.items[destIndex];
    if (!dest.isEmpty()) return false;
    return canAddAt(destIndex) && canPlaceTile(destIndex, tile);
  }

  /// Performs an orthogonal relocate.
  static OrthogonalMoveResult tryOrthogonallyRelocate(
    GridList<Tile> grid,
    int sourceIndex,
    int destIndex,
    Tile tile, {
    required bool Function(int index) canAddAt,
    required bool Function(int index, Tile tile) canPlaceTile,
    required Tile Function() getEmpty,
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
    if (!grid.items[destIndex].isEmpty()) {
      if (canInsertPushUpward(
        grid,
        sourceIndex,
        destIndex,
        movingTile: tile,
      )) {
        insertPushUpward(
          grid,
          sourceIndex,
          destIndex,
          tile,
          getEmpty: getEmpty,
        );
        return OrthogonalMoveResult.pushed;
      }
      if (canInsertPushDownward(
        grid,
        sourceIndex,
        destIndex,
        movingTile: tile,
      )) {
        insertPushDownward(
          grid,
          sourceIndex,
          destIndex,
          tile,
          getEmpty: getEmpty,
        );
        return OrthogonalMoveResult.pushed;
      }
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
  /// Cross-ground insert that shifted the destination stack up or down.
  pushed,
}

/// All placeable categories including token strip types.
const List<TileType> kAllPickerTileTypes = [
  TileType.Food,
  TileType.Living,
  TileType.Utility,
  TileType.Outdoor,
  TileType.Sleeping,
  TileType.Activity,
  TileType.Corridor,
  TileType.Secret,
  TileType.Downstairs,
  TileType.Special,
  TileType.RoyalAttendant,
  TileType.BonusCard,
];

/// Structural castle picker categories (rooms only).
const List<TileType> kStructuralPickerTileTypes = [
  TileType.Food,
  TileType.Living,
  TileType.Utility,
  TileType.Outdoor,
  TileType.Sleeping,
  TileType.Activity,
  TileType.Corridor,
  TileType.Secret,
  TileType.Downstairs,
  TileType.Special,
];
