import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/grid_expander.dart';

/// Placement rules for castle grid editing.
class TilePlacement {
  TilePlacement._();

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

  /// Whether [tile] may be newly placed at [index] given outdoor stacking rules.
  /// Existing camera placements above Outdoor are kept and badged in the UI;
  /// use [allowAboveOutdoor] when replacing an already-occupied cell.
  static bool canPlaceTile(
    GridList<Tile> grid,
    int index,
    Tile tile, {
    bool allowAboveOutdoor = false,
  }) {
    if (!allowAboveOutdoor && isDirectlyAboveOutdoor(grid, index)) {
      return false;
    }
    if (tile.tileType == TileType.Outdoor &&
        wouldPutOutdoorUnderTile(grid, index)) {
      return false;
    }
    return true;
  }

  /// Occupied cell that sits directly above an Outdoor tile.
  static bool hasInvalidAboveOutdoorPlacement(GridList<Tile> grid, int index) {
    if (index < 0 || index >= grid.items.length) return false;
    final tile = grid.items[index];
    if (tile.isEmpty() || tile.tileType == TileType.Placeholder) return false;
    return isDirectlyAboveOutdoor(grid, index);
  }
}
