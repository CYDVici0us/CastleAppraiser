import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/widgets/tile/tile_type_widget.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart';

/// Placeable tile categories for the nested picker (excludes Empty, Placeholder, ThroneRoom).
const List<TileType> kPlaceableTileTypes = [
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
/// Returns the chosen [Tile], or null if cancelled.
Future<Tile?> showTilePickerDialog({
  required BuildContext context,
  required List<Tile> availableTiles,
}) {
  return showDialog<Tile>(
    context: context,
    builder: (context) => TilePickerDialog(availableTiles: availableTiles),
  );
}

class TilePickerDialog extends StatelessWidget {
  final List<Tile> availableTiles;

  const TilePickerDialog({super.key, required this.availableTiles});

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
            builder: (_) => _TileCategoryPage(availableTiles: availableTiles),
          ),
        ),
      ),
    );
  }
}

class _TileCategoryPage extends StatelessWidget {
  final List<Tile> availableTiles;

  const _TileCategoryPage({required this.availableTiles});

  @override
  Widget build(BuildContext context) {
    final typesWithTiles = kPlaceableTileTypes.where((type) {
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
                              .toList()
                            ..sort((a, b) => a.name.compareTo(b.name)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tileTypeDisplayName(type)),
      ),
      body: tiles.isEmpty
          ? const Center(child: Text('No tiles in this category'))
          : ListView.builder(
              itemCount: tiles.length,
              itemBuilder: (context, index) {
                final tile = tiles[index];
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

class _CategoryLeading extends StatelessWidget {
  final TileType type;

  const _CategoryLeading({required this.type});

  @override
  Widget build(BuildContext context) {
    if (_tileTypeHasCategoryImage(type)) {
      return TileTypeWidget(type, scale: 0.5);
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

    return SizedBox(
      width: TileWidget.defaultTileWidthHeight * 0.5,
      height: TileWidget.defaultTileWidthHeight * 0.5,
      child: Icon(icon, size: 32),
    );
  }
}
