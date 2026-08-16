import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/tile_placement.dart';
import 'package:btcc/src/utils/token_tile_grid.dart';
import 'package:btcc/src/widgets/tile/tile_type_widget.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart';

/// Placeable tile categories for the nested picker (excludes Empty, Placeholder, ThroneRoom).
const List<TileType> kPlaceableTileTypes = kAllPickerTileTypes;

bool _tileTypeHasCategoryImage(TileType type) {
  switch (type) {
    case TileType.Corridor:
    case TileType.Downstairs:
    case TileType.Food:
    case TileType.Living:
    case TileType.Outdoor:
    case TileType.Sleeping:
    case TileType.Utility:
    case TileType.Secret:
    case TileType.Activity:
      return true;
    default:
      return false;
  }
}

String tileTypeDisplayName(TileType type) {
  switch (type) {
    case TileType.RoyalAttendant:
      return 'Royal Attendant';
    case TileType.BonusCard:
      return 'Bonus Card';
    case TileType.ThroneRoom:
      return 'Throne Room';
    default:
      return type.toString().split('.').last;
  }
}

/// Shows a nested dialog: category list, then tiles filtered from [availableTiles].
/// When [allowedTypes] is set, only those categories are shown.
/// Returns the chosen [Tile], or null if cancelled.
Future<Tile?> showTilePickerDialog({
  required BuildContext context,
  required List<Tile> availableTiles,
  List<TileType>? allowedTypes,
}) {
  return showDialog<Tile>(
    context: context,
    builder: (context) => TilePickerDialog(
      availableTiles: availableTiles,
      allowedTypes: allowedTypes,
    ),
  );
}

/// Horizontal throne-room picker. Returns the chosen throne, or null if dismissed.
Future<Tile?> showThroneRoomPickerDialog(BuildContext context) {
  final trs = TileHelper().getAllThroneRooms();
  return showDialog<Tile>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose a throne room'),
          SizedBox(
            height: TileWidget.defaultTileWidthHeight,
            width: MediaQuery.of(context).size.width * .8,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: trs.length,
              itemBuilder: (_, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: InkWell(
                  child: TileWidget(trs[index]),
                  onTap: () => Navigator.pop(ctx, trs[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class TilePickerDialog extends StatelessWidget {
  final List<Tile> availableTiles;
  final List<TileType>? allowedTypes;

  const TilePickerDialog({
    super.key,
    required this.availableTiles,
    this.allowedTypes,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.7,
        child: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => _TileCategoryPage(
              availableTiles: availableTiles,
              allowedTypes: allowedTypes ?? kPlaceableTileTypes,
            ),
          ),
        ),
      ),
    );
  }
}

class _TileCategoryPage extends StatelessWidget {
  final List<Tile> availableTiles;
  final List<TileType> allowedTypes;

  const _TileCategoryPage({
    required this.availableTiles,
    required this.allowedTypes,
  });

  @override
  Widget build(BuildContext context) {
    final typesWithTiles = allowedTypes.where((type) {
      return availableTiles.any((tile) => tile.tileType == type);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose type'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ),
      body: typesWithTiles.isEmpty
          ? const Center(child: Text('No tiles available'))
          : ListView.builder(
              itemCount: typesWithTiles.length,
              itemBuilder: (context, index) {
                final type = typesWithTiles[index];
                final count =
                    availableTiles.where((t) => t.tileType == type).length;
                return ListTile(
                  leading: _CategoryLeading(type: type),
                  title: Text(tileTypeDisplayName(type)),
                  subtitle: Text('$count available'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _TileListPage(
                          type: type,
                          tiles: availableTiles
                              .where((t) => t.tileType == type)
                              .toList(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _TileListPage extends StatelessWidget {
  final TileType type;
  final List<Tile> tiles;

  const _TileListPage({required this.type, required this.tiles});

  /// Bonus / attendant / special use large cards with readable labels.
  bool get _useLargePickerCard =>
      TokenTileGrid.isTokenType(type) || type == TileType.Special;

  List<Tile> get _sortedTiles {
    final sorted = List<Tile>.from(tiles);
    if (_useLargePickerCard) {
      sorted.sort((a, b) => TokenTileGrid.displayName(a)
          .compareTo(TokenTileGrid.displayName(b)));
      if (type == TileType.Special) {
        // One entry per distinct special (Tower×5 / BallRoom×2 duplicates).
        final seen = <String>{};
        sorted.retainWhere((t) => seen.add(TokenTileGrid.displayName(t)));
      }
    } else {
      sorted.sort((a, b) => a.name.compareTo(b.name));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final items = _sortedTiles;
    return Scaffold(
      appBar: AppBar(
        title: _useLargePickerCard
            ? Row(
                children: [
                  _CategoryLeading(type: type, compact: true),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      tileTypeDisplayName(type),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(tileTypeDisplayName(type)),
      ),
      body: items.isEmpty
          ? const Center(child: Text('No tiles in this category'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final tile = items[index];
                if (_useLargePickerCard) {
                  return _LargePickerCard(
                    tile: tile,
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).pop(tile),
                  );
                }
                return ListTile(
                  leading: TileWidget(
                    tile,
                    scale: 0.6,
                  ),
                  title: Text(tile.name),
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pop(tile);
                  },
                );
              },
            ),
    );
  }
}

/// Larger picker row for specials / bonus / attendants with readable labels.
class _LargePickerCard extends StatelessWidget {
  final Tile tile;
  final VoidCallback onTap;

  const _LargePickerCard({
    required this.tile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = TokenTileGrid.displayName(tile);
    final scoring = TokenTileGrid.scoringDescription(tile);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TileWidget(tile, scale: 1.05),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (scoring.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        scoring,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryLeading extends StatelessWidget {
  final TileType type;
  final bool compact;

  const _CategoryLeading({
    required this.type,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scale = compact ? 0.36 : 0.5;
    if (_tileTypeHasCategoryImage(type)) {
      return TileTypeWidget(type, scale: scale);
    }

    // Special / RoyalAttendant / BonusCard have no category scoring image.
    IconData icon;
    switch (type) {
      case TileType.Special:
        icon = Icons.star;
        break;
      case TileType.RoyalAttendant:
        icon = Icons.person;
        break;
      case TileType.BonusCard:
        icon = Icons.style;
        break;
      default:
        icon = Icons.grid_view;
    }

    final size = TileWidget.defaultTileWidthHeight * scale;
    return SizedBox(
      width: size,
      height: size,
      child: Icon(icon, size: compact ? 22 : 32),
    );
  }
}
