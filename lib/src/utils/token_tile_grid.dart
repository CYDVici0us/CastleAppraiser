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

  /// Camera / game convention: at most two bonus cards per castle.
  static const int maxBonusCardsPerCastle = 2;

  /// Camera / game convention: at most two royal attendants per castle.
  static const int maxRoyalAttendantsPerCastle = 2;

  /// The four attendant roles (duplicates like Jester2 are the same type).
  static const List<TileId> canonicalRoyalAttendantIds = [
    TileId.RoyalAttendantTaylor,
    TileId.RoyalAttendantJester,
    TileId.RoyalAttendantKnight,
    TileId.RoyalAttendantPainter,
  ];

  /// Shared type key for attendant copies (Jester / Jester2 → same name).
  static String attendantTypeKey(Tile tile) => tile.name;

  static List<Tile> _tokensExcluding(
    List<Tile> tokens,
    Tile? replacing,
  ) {
    if (replacing == null) return tokens;
    return tokens.where((t) => t.id != replacing.id).toList();
  }

  static bool canAddMoreBonusCards(
    List<Tile> tokens, {
    Tile? replacing,
  }) {
    final count = _tokensExcluding(tokens, replacing)
        .where((t) => t.isBonusCard())
        .length;
    return count < maxBonusCardsPerCastle;
  }

  static bool canAddMoreAttendants(
    List<Tile> tokens, {
    Tile? replacing,
  }) {
    final count = _tokensExcluding(tokens, replacing)
        .where((t) => t.isRoyalAttendant())
        .length;
    return count < maxRoyalAttendantsPerCastle;
  }

  static bool canAddAnyToken(List<Tile> tokens) =>
      canAddMoreBonusCards(tokens) || canAddMoreAttendants(tokens);

  /// Inventory for the strip picker: unused bonus cards (if under max) and
  /// up to the four attendant types not already on the castle (if under max).
  static List<Tile> filterTokenPickerTiles({
    required List<Tile> inventory,
    required List<Tile> currentTokens,
    Tile? replacing,
  }) {
    final effective = _tokensExcluding(currentTokens, replacing);
    final allowBonus = canAddMoreBonusCards(currentTokens, replacing: replacing);
    final allowAttendant =
        canAddMoreAttendants(currentTokens, replacing: replacing);

    final usedBonusIds = {
      for (final t in effective)
        if (t.isBonusCard()) t.id,
    };
    final usedAttendantTypes = {
      for (final t in effective)
        if (t.isRoyalAttendant()) attendantTypeKey(t),
    };

    final result = <Tile>[];
    final seenAttendantTypes = <String>{};

    for (final tile in inventory) {
      if (tile.isBonusCard()) {
        if (!allowBonus) continue;
        if (usedBonusIds.contains(tile.id)) continue;
        result.add(tile);
        continue;
      }

      if (tile.isRoyalAttendant()) {
        if (!allowAttendant) continue;
        if (!canonicalRoyalAttendantIds.contains(tile.id)) continue;
        final key = attendantTypeKey(tile);
        if (usedAttendantTypes.contains(key)) continue;
        if (!seenAttendantTypes.add(key)) continue;
        result.add(tile);
      }
    }

    return result;
  }

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
  /// Tokens are left-aligned in that row.
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

  /// Readable title for picker / strip UI.
  static String displayName(Tile tile) {
    var name = tile.name;

    // BallRoomPerUtility → "Ball Room · Utility"
    if (name.startsWith('BallRoom')) {
      var rest = name.substring('BallRoom'.length);
      if (rest.startsWith('Per')) rest = rest.substring(3);
      final condition = humanizeCamelCase(rest);
      return condition.isEmpty ? 'Ball Room' : 'Ball Room · $condition';
    }

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
    final spaced = humanizeCamelCase(name);
    return spaced.isEmpty ? tile.name : spaced;
  }

  /// Scoring-grid label: keeps type words ("Bonus Card", "Royal Attendant").
  static String scoringLabel(Tile tile) {
    if (tile.isBonusCard()) {
      final detail = displayName(tile);
      return detail.isEmpty ? 'Bonus Card' : 'Bonus Card · $detail';
    }
    if (tile.isRoyalAttendant()) {
      final detail = displayName(tile);
      if (detail.isEmpty || detail == 'Royal Attendant') {
        return 'Royal Attendant';
      }
      return 'Royal Attendant · $detail';
    }
    return displayName(tile);
  }

  static String humanizeCamelCase(String name) {
    return name
        .replaceAllMapped(
          RegExp(r'(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])'),
          (m) => ' ',
        )
        .trim();
  }

  /// Short scoring blurb for picker / selected token details.
  static String scoringDescription(Tile tile) {
    if (tile.isRoyalAttendant()) {
      final condition = _enumLabel(tile.scoringCondition);
      return '+${tile.scorePer} per $condition in castle';
    }

    if (tile.tileType == TileType.Special) {
      final per = tile.scorePer;
      if (tile.name.startsWith('BallRoom')) {
        final condition = humanizeCamelCase(_enumLabel(tile.scoringCondition));
        return '+$per per $condition in neighboring castles';
      }
      if (tile.scoringCondition == ScoringCondition.Always) {
        return '+$per';
      }
      final positions = tile.scoringPositions;
      if (positions.contains(ScoringPosition.Below)) {
        return '+$per per room below';
      }
      if (positions.contains(ScoringPosition.Above)) {
        return '+$per per room above';
      }
      if (positions.length >= 4) {
        final condition = tile.scoringCondition == ScoringCondition.Any
            ? 'room'
            : humanizeCamelCase(_enumLabel(tile.scoringCondition));
        return '+$per per surrounding $condition';
      }
      if (per != 0) return '+$per';
      return '';
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
