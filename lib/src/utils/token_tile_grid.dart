import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/tile_placement.dart';

/// Bonus cards and royal attendants — scored tokens, not structural rooms.
class TokenTileGrid {
  TokenTileGrid._();

  static bool isTokenTile(Tile tile) =>
      tile.isBonusCard() || tile.isRoyalAttendant();

  static bool isTokenType(TileType type) =>
      type == TileType.BonusCard || type == TileType.RoyalAttendant;

  /// Types shown in the Bonus & Royal strip picker.
  static const List<TileType> stripPickerTypes = [
    TileType.BonusCard,
    TileType.RoyalAttendant,
  ];

  /// Pulls token tiles out of [grid], replacing them with [getEmpty], then
  /// packs remaining rooms toward the throne/ground to close holes.
  /// Returns tokens in row-major order (bonus/royal as found).
  static ({List<Tile> tokens, GridList<Tile> structural}) extractTokenTiles(
    GridList<Tile> grid, {
    required Tile Function() getEmpty,
  }) {
    final tokens = <Tile>[];
    final items = List<Tile>.from(grid.items);
    for (int i = 0; i < items.length; i++) {
      if (isTokenTile(items[i])) {
        tokens.add(items[i]);
        items[i] = getEmpty();
      }
    }
    final structural = GridList<Tile>(grid.width, items);
    // Column then row, twice, so vertical then horizontal fills settle.
    TilePlacement.compactTowardGround(structural, getEmpty: getEmpty);
    TilePlacement.compactTowardGround(structural, getEmpty: getEmpty);
    return (
      tokens: tokens,
      structural: structural,
    );
  }

  /// Prepends a top row for [tokens] above [structural] so tokens sit above
  /// the structural perimeter and do not touch castle rooms.
  static GridList<Tile> mergeTokenTilesIntoGrid(
    GridList<Tile> structural,
    List<Tile> tokens, {
    required Tile Function() getEmpty,
  }) {
    if (tokens.isEmpty) {
      return GridList<Tile>(structural.width, List<Tile>.from(structural.items));
    }

    final width = structural.width > tokens.length
        ? structural.width
        : tokens.length;
    final height = structural.height + 1;
    final items = List<Tile>.generate(width * height, (_) => getEmpty());

    for (int i = 0; i < tokens.length; i++) {
      items[i] = tokens[i];
    }

    for (int y = 0; y < structural.height; y++) {
      for (int x = 0; x < structural.width; x++) {
        final src = x + y * structural.width;
        final dest = x + (y + 1) * width;
        items[dest] = structural.items[src];
      }
    }

    return GridList<Tile>(width, items);
  }

  static String _enumLabel(Object value) =>
      value.toString().split('.').last;

  /// Readable title for strip UI (spaces CamelCase / strips BonusCard prefix).
  static String displayName(Tile tile) {
    var name = tile.name;
    if (name.startsWith('BonusCard')) {
      name = name.substring('BonusCard'.length);
    }
    if (name.startsWith('Per')) {
      name = name.substring(3);
    }
    if (name.startsWith('RoyalAttendant')) {
      name = name.substring('RoyalAttendant'.length);
      if (name.isEmpty) name = 'Royal Attendant';
    }
    // Insert spaces before capitals: RoomsAboveLevelThree -> Rooms Above Level Three
    name = name.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])'),
      (m) => ' ',
    );
    return name.trim().isEmpty ? tile.name : name.trim();
  }

  /// Short scoring blurb for the selected token.
  static String scoringDescription(Tile tile) {
    if (tile.isRoyalAttendant()) {
      final condition = _enumLabel(tile.scoringCondition);
      return '+${tile.scorePer} per $condition in castle';
    }
    if (!tile.isBonusCard()) return '';

    final per = tile.scorePer;
    switch (tile.id) {
      case TileId.BCPerRoomsAboveLevelThree:
        return '+$per per room above level 3';
      case TileId.BCPerTotalOrdinallySurrounded:
        return '+$per per fully surrounded room (ordinal)';
      case TileId.BCPerRoyalAttendant:
        return '+$per per royal attendant';
      case TileId.BCPerUtility:
        return '+$per per Utility room';
      case TileId.BCPerOutdoor:
        return '+$per per Outdoor room';
      case TileId.BCPerFiveOfSameType:
        return '+$per per room type with 5+ rooms';
      case TileId.BCPerDownstairs:
        return '+$per per Downstairs room';
      case TileId.BCPerUniqueRoomAroundThroneRoom:
        return '+$per per unique room type around throne';
      case TileId.BCPerThreeOfSameType:
        return '+$per per room type with 3+ rooms';
      case TileId.BCPerTotalCardinallySurrounded:
        return '+$per per fully surrounded room (cardinal)';
      case TileId.BCPerLiving:
        return '+$per per Living room';
      case TileId.BCPerRoomsOrdinallyAroundThroneRoom:
        return '+$per per room around the throne';
      case TileId.BCPerTotalWidth:
        return '+$per per castle width';
      case TileId.BCPerRoomsBelowGround:
        return '+$per per room below ground';
      case TileId.BCPerSpecial:
        return '+$per per Special room';
      case TileId.BCPerCorridor:
        return '+$per per Corridor';
      case TileId.BCPerTotalHeight:
        return '+$per per castle height';
      case TileId.BCPerSleeping:
        return '+$per per Sleeping room';
      case TileId.BCPerFood:
        return '+$per per Food room';
      case TileId.BCPerRegularAndSpecialtyRoomType:
        return '+$per per unique room type in castle';
      case TileId.BCPerActivity:
        return '+$per per Activity room';
      case TileId.BCPerMirror:
        return '+$per per Mirror';
      case TileId.BCPerPainting:
        return '+$per per Painting';
      case TileId.BCPerSwords:
        return '+$per per Swords';
      case TileId.BCPerTorch:
        return '+$per per Torch';
      case TileId.BCPerSpecialSet:
        return '+$per per complete ornament set';
      case TileId.BCPerSecret:
        return '+$per per Secret room';
      case TileId.BCPerSpecialInNeighborCastles:
        return '+$per per Special room in neighboring castles';
      default:
        return tile.scorePer != 0 ? '+${tile.scorePer} (bonus card)' : 'Bonus card';
    }
  }
}
