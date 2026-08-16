import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/tile_placement.dart';
import 'package:btcc/src/utils/token_tile_grid.dart';
import 'package:btcc/src/widgets/tile/scoring_blurb.dart';
import 'package:btcc/src/widgets/tile/scoring_placement_grid.dart';
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

/// Large-card throne room picker (same style as Bonus/Attendant).
/// Returns the chosen throne, or null if dismissed.
Future<Tile?> showThroneRoomPickerDialog(BuildContext context) {
  final trs = TileHelper().getAllThroneRooms();
  final size = MediaQuery.of(context).size;
  return showDialog<Tile>(
    context: context,
    builder: (ctx) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.7,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Choose a Throne Room'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: trs.length,
            itemBuilder: (_, index) {
              final tile = trs[index];
              return _ThronePickerCard(
                tile: tile,
                onTap: () => Navigator.pop(ctx, tile),
              );
            },
          ),
        ),
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

  /// Deduplicate specials that share a display name (Tower×5 / BallRoom×2).
  bool get _dedupeByDisplayName => type == TileType.Special;

  String _specialDedupeKey(Tile tile) {
    // Ball rooms share the heading "Ball Room"; keep one per variant name
    // (collapses BallRoomPerUtility / BallRoomPerUtility2).
    if (tile.name.startsWith('BallRoom')) return tile.name;
    return TokenTileGrid.displayName(tile);
  }

  List<Tile> get _sortedTiles {
    final sorted = List<Tile>.from(tiles);
    sorted.sort((a, b) {
      if (type == TileType.Special) {
        final aBall = a.name.startsWith('BallRoom');
        final bBall = b.name.startsWith('BallRoom');
        if (aBall != bBall) return aBall ? 1 : -1;
      }
      final byName =
          _pickerDisplayName(a).compareTo(_pickerDisplayName(b));
      if (byName != 0) return byName;
      return a.name.compareTo(b.name);
    });
    if (_dedupeByDisplayName) {
      final seen = <String>{};
      sorted.retainWhere((t) => seen.add(_specialDedupeKey(t)));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final items = _sortedTiles;
    return Scaffold(
      appBar: AppBar(
        title: Row(
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
        ),
      ),
      body: items.isEmpty
          ? const Center(child: Text('No tiles in this category'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final tile = items[index];
                return _LargePickerCard(
                  tile: tile,
                  onTap: () =>
                      Navigator.of(context, rootNavigator: true).pop(tile),
                );
              },
            ),
    );
  }
}

String _pickerDisplayName(Tile tile) {
  if (TokenTileGrid.isTokenType(tile.tileType) ||
      tile.tileType == TileType.Special) {
    return TokenTileGrid.displayName(tile);
  }
  return tile.name;
}

/// Larger picker row with readable labels (all placeable tile types).
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
    final name = _pickerDisplayName(tile);
    final showScoring = ScoringBlurb.hasContent(tile);
    final showGrid = ScoringPlacementMapping.shouldShow(tile);
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );

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
                    ScoringBlurb.titleWithCategories(
                      title: name,
                      style: titleStyle,
                    ),
                    if (showScoring) ...[
                      const SizedBox(height: 6),
                      ScoringBlurb(tile: tile),
                    ],
                    if (showGrid) ...[
                      const SizedBox(height: 10),
                      ScoringPlacementGrid.forTile(tile, cellSize: 16),
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

/// Large throne picker card with scoring lines + placement grid.
class _ThronePickerCard extends StatelessWidget {
  final Tile tile;
  final VoidCallback onTap;

  const _ThronePickerCard({
    required this.tile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showScoring = ScoringBlurb.hasContent(tile);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  // Fill card width; height stays half (2×1 rectangle).
                  final scale = constraints.maxWidth /
                      (TileWidget.defaultTileWidthHeight * 2);
                  return TileWidget(tile, scale: scale);
                },
              ),
              if (showScoring) ...[
                const SizedBox(height: 12),
                ScoringBlurb(
                  tile: tile,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 10),
              Center(
                child: ScoringPlacementGrid.throne(
                  positions: tile.scoringPositions,
                  cellSize: 14,
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
