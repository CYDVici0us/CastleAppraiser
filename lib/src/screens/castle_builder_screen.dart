import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/analytics/analytics.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/tile_placement.dart';
import 'package:btcc/src/utils/token_tile_grid.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/builder/drag_and_drop_grid.dart';
import 'package:btcc/src/widgets/builder/expandable_grid_map_view.dart';
import 'package:btcc/src/widgets/builder/filtered_drag_and_drop_list_view.dart';
import 'package:btcc/src/widgets/builder/tile_picker_sheet.dart';
import 'package:btcc/src/widgets/button_padding.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'dart:math';

class DraggedTileInfo {
  final int index;
  final Tile tile;
  DraggedTileInfo(this.index, this.tile);
}

class CastleBuilderScreen extends StatefulWidget {
  final int numPicturesTaken;
  final GridList<Tile> castleTiles;
  final String? imagePath;
  final AddCastleToGameCallback? addCastleCallback;
  final UpdateCastleCallback? updateCastleCallback;
  final Castle? existingCastle;
  final String? gameTitle;

  CastleBuilderScreen({
    required this.castleTiles,
    this.imagePath,
    this.addCastleCallback,
    this.updateCastleCallback,
    this.existingCastle,
    this.numPicturesTaken = 0,
    this.gameTitle,
  });

  @override
  _CastleBuilderScreenState createState() => new _CastleBuilderScreenState();
}

class _CastleBuilderScreenState extends State<CastleBuilderScreen> {
  late TextEditingController _textEditingController;

  String _filterText = '';
  List<Tile> _allTiles = [];
  late GridList<Tile> _castleTiles;
  /// Bonus cards + royal attendants (not on the structural map).
  List<Tile> _tokenTiles = [];
  int? _selectedTokenIndex;
  DraggedTileInfo? _draggingTile;
  late Castle _castle;
  int? _selectedIndex;
  /// Set while a grid tile is being dragged (cell already emptied).
  int? _gridDragSourceIndex;

  static bool _isOccupied(Tile tile) => !tile.isEmpty();

  @override
  void initState() {
    super.initState();

    _textEditingController = new TextEditingController();
    final extracted = TokenTileGrid.extractTokenTiles(
      widget.castleTiles,
      getEmpty: () => Empty(),
    );
    _tokenTiles = extracted.tokens;
    final normalized = GridListNormalizer.normalizePerimeter(
      extracted.structural,
      isOccupied: _isOccupied,
      getEmpty: () => Empty(),
    );
    _castleTiles = normalized.grid;
    _refreshAvailableTiles();
    _syncCastleFromParts();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  GridList<Tile> _mergedGrid() => TokenTileGrid.mergeTokenTilesIntoGrid(
        _castleTiles,
        _tokenTiles,
        getEmpty: () => Empty(),
      );

  void _syncCastleFromParts() {
    _castle = Castle(_mergedGrid());
  }

  void _refreshAvailableTiles() {
    _allTiles = TileHelper().getListOfTilesExcludingTilesAndTrs([
      ..._castleTiles.items,
      ..._tokenTiles,
    ]);
  }

  bool _canAddAt(int index) {
    if (TilePlacement.isDirectlyAboveOutdoor(_castleTiles, index)) {
      return false;
    }
    if (GridListNormalizer.canPlaceAdjacent(
      _castleTiles,
      index,
      isOccupied: _isOccupied,
    )) {
      return true;
    }
    // Holes left after removing a room inside the castle footprint.
    return GridListNormalizer.isEmptyInsideOccupiedBounds(
      _castleTiles,
      index,
      isOccupied: _isOccupied,
    );
  }

  bool _canPlaceTileAt(
    int index,
    Tile tile, {
    bool allowAboveOutdoor = false,
    bool requireSupport = false,
  }) =>
      TilePlacement.canPlaceTile(
        _castleTiles,
        index,
        tile,
        allowAboveOutdoor: allowAboveOutdoor,
        requireSupport: requireSupport,
      );

  List<TileType>? _allowedTypesForIndex(int index) {
    final level = TilePlacement.levelRelativeToGround(_castleTiles, index);
    if (level == null) return null;
    return TilePlacement.allowedPickerTypesForLevel(level);
  }

  bool _canDropTarget(int index, Tile cell) {
    final source = _gridDragSourceIndex;
    if (source != null) {
      if (index == source) return false;
      if (TilePlacement.isOrthogonal(_castleTiles, source, index)) {
        // Need the dragged tile for type checks when crossing the throne.
        // During drag the source cell is empty; use accept with tile from DnD.
        // Drop target only needs geometry: rotate OK, or empty legal hole.
        if (TilePlacement.canRotateSegment(_castleTiles, source, index)) {
          return true;
        }
        return cell.isEmpty() && _canAddAt(index);
      }
      return cell.isEmpty() && _canAddAt(index);
    }
    return cell.isEmpty() && _canAddAt(index);
  }

  bool _canAcceptDraggedTile(int index, Tile tile) {
    final source = _gridDragSourceIndex;
    if (source != null) {
      if (index == source) return false;
      if (TilePlacement.isOrthogonal(_castleTiles, source, index)) {
        return TilePlacement.canOrthogonallyRelocate(
          _castleTiles,
          source,
          index,
          tile,
          canAddAt: _canAddAt,
          canPlaceTile: (i, t) => _canPlaceTileAt(i, t),
        );
      }
      return _castleTiles.items[index].isEmpty() &&
          _canAddAt(index) &&
          _canPlaceTileAt(index, tile);
    }
    return _canPlaceTileAt(index, tile);
  }

  GridNormalizeResult<Tile> _normalize(GridList<Tile> grid) =>
      GridListNormalizer.normalizePerimeter(
        grid,
        isOccupied: _isOccupied,
        getEmpty: () => Empty(),
      );

  void _updateCastle(GridList<Tile> copy) {
    setState(() {
      _castleTiles = copy;
      _syncCastleFromParts();
      _draggingTile = null;
    });
  }

  void _onTapCell(int index) {
    final tile = _castleTiles.items[index];
    if (tile.tileType == TileType.Placeholder) {
      return;
    }
    setState(() {
      _selectedIndex = index;
      _selectedTokenIndex = null;
    });
  }

  Future<void> _openTilePickerForSelected() async {
    final index = _selectedIndex;
    if (index == null) return;

    final chosen = await showTilePickerDialog(
      context: context,
      availableTiles: List<Tile>.from(_allTiles),
      allowedTypes: _allowedTypesForIndex(index),
    );
    if (chosen == null || !mounted) return;

    _placeTileAt(index, chosen);
  }

  void _placeTileAt(int index, Tile tile) {
    final existing = _castleTiles.items[index];
    if (existing.isEmpty()) {
      if (!_canAddAt(index) || !_canPlaceTileAt(index, tile)) {
        return;
      }
    } else if (!_canPlaceTileAt(
      index,
      tile,
      allowAboveOutdoor: true,
      requireSupport: false,
    )) {
      return;
    }

    var copy = _castleTiles;
    copy.items[index] = tile;
    final normalized = _normalize(copy);
    final mapped = normalized.mapIndex(index);

    setState(() {
      _castleTiles = normalized.grid;
      _draggingTile = null;
      _gridDragSourceIndex = null;
      _refreshAvailableTiles();
      _syncCastleFromParts();
      _selectedIndex = mapped;
      _selectedTokenIndex = null;
    });
  }

  void _removeSelectedTile() {
    final index = _selectedIndex;
    if (index == null) return;
    final tile = _castleTiles.items[index];
    if (!tile.isMovable()) return;

    final copy = _castleTiles;
    copy.items[index] = Empty();
    TilePlacement.compactTowardGround(copy, getEmpty: () => Empty());
    final normalized = _normalize(copy);
    final mapped = normalized.mapIndex(index);

    setState(() {
      _castleTiles = normalized.grid;
      _draggingTile = null;
      _gridDragSourceIndex = null;
      _refreshAvailableTiles();
      _syncCastleFromParts();
      _selectedIndex = mapped;
      _selectedTokenIndex = null;
    });
  }

  void _applyGridDrop(int index, Tile item) {
    final source = _gridDragSourceIndex;
    var copy = _castleTiles;

    if (source != null &&
        TilePlacement.isOrthogonal(copy, source, index)) {
      final result = TilePlacement.tryOrthogonallyRelocate(
        copy,
        source,
        index,
        item,
        canAddAt: (i) {
          if (TilePlacement.isDirectlyAboveOutdoor(copy, i)) return false;
          if (GridListNormalizer.canPlaceAdjacent(
            copy,
            i,
            isOccupied: _isOccupied,
          )) {
            return true;
          }
          return GridListNormalizer.isEmptyInsideOccupiedBounds(
            copy,
            i,
            isOccupied: _isOccupied,
          );
        },
        canPlaceTile: (i, t) => TilePlacement.canPlaceTile(
          copy,
          i,
          t,
          requireSupport: false,
        ),
      );
      if (result == OrthogonalMoveResult.relocated) {
        TilePlacement.compactTowardGround(copy, getEmpty: () => Empty());
      }
      if (result != OrthogonalMoveResult.failed) {
        final normalized = _normalize(copy);
        setState(() {
          _castleTiles = normalized.grid;
          _draggingTile = null;
          _gridDragSourceIndex = null;
          _refreshAvailableTiles();
          _syncCastleFromParts();
          _selectedIndex = null;
          _selectedTokenIndex = null;
        });
        return;
      }
    }

    if (item.tileType == TileType.ThroneRoom) {
      copy.items[index] = item;
      if (index + 1 >= copy.items.length) {
        copy.items.add(Placeholder());
      } else {
        copy.items[index + 1] = Placeholder();
      }
    } else {
      copy.items[index] = item;
      if (source != null) {
        TilePlacement.compactTowardGround(copy, getEmpty: () => Empty());
      }
    }

    final normalized = _normalize(copy);
    setState(() {
      _castleTiles = normalized.grid;
      _draggingTile = null;
      _gridDragSourceIndex = null;
      _refreshAvailableTiles();
      _syncCastleFromParts();
      _selectedIndex = null;
      _selectedTokenIndex = null;
    });
  }

  Future<void> _openTokenPicker({int? replaceIndex}) async {
    final chosen = await showTilePickerDialog(
      context: context,
      availableTiles: List<Tile>.from(_allTiles),
      allowedTypes: TokenTileGrid.stripPickerTypes,
    );
    if (chosen == null || !mounted) return;
    if (!TokenTileGrid.isTokenTile(chosen)) return;

    setState(() {
      if (replaceIndex != null &&
          replaceIndex >= 0 &&
          replaceIndex < _tokenTiles.length) {
        _tokenTiles[replaceIndex] = chosen;
      } else {
        _tokenTiles.add(chosen);
      }
      _selectedTokenIndex = replaceIndex ?? _tokenTiles.length - 1;
      _selectedIndex = null;
      _refreshAvailableTiles();
      _syncCastleFromParts();
    });
  }

  void _removeSelectedToken() {
    final index = _selectedTokenIndex;
    if (index == null || index < 0 || index >= _tokenTiles.length) return;
    setState(() {
      _tokenTiles.removeAt(index);
      _selectedTokenIndex = null;
      _refreshAvailableTiles();
      _syncCastleFromParts();
    });
  }

  void _showThroneRoomPicker() {
    var trs = TileHelper().getAllThroneRooms();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose a throne room'),
            Container(
              height: TileWidget.defaultTileWidthHeight,
              width: MediaQuery.of(context).size.width * .8,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: trs.length,
                itemBuilder: (ctx, index) => Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.0),
                  child: InkWell(
                    child: TileWidget(
                      trs[index],
                    ),
                    onTap: () {
                      var copy = _castleTiles;
                      int i = copy.items.indexWhere(
                          (element) => element.tileType == TileType.ThroneRoom);
                      copy.items.replaceRange(i, i + 1, [trs[index]]);
                      _updateCastle(copy);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  static String _enumLabel(Object value) => value.toString().split('.').last;

  String? _tileScoringSummary(Tile tile) {
    if (tile.isEmpty() || tile.isPlaceholder()) return null;

    final parts = <String>[];

    if (tile.scoringCondition != ScoringCondition.None) {
      final condition = _enumLabel(tile.scoringCondition);
      final positions = tile.scoringPositions;
      String where = '';
      if (positions.contains(ScoringPosition.Type)) {
        where = ' in castle';
      } else if (positions.contains(ScoringPosition.Connected)) {
        where = ' connected';
      } else if (positions.contains(ScoringPosition.Neighbor)) {
        where = ' adjacent';
      } else if (positions.isNotEmpty) {
        where = ' (${positions.map(_enumLabel).join(', ')})';
      }
      if (tile.scorePer != 0) {
        parts.add('+${tile.scorePer} per $condition$where');
      } else {
        parts.add(condition + where);
      }
    } else if (tile.scorePer != 0) {
      parts.add('+${tile.scorePer}');
    }

    if (tile.throneRoomCondition != ScoringCondition.None) {
      parts.add('+${tile.scorePer} per ${_enumLabel(tile.throneRoomCondition)}');
    }

    if (tile.decorationType != DecorationType.None) {
      parts.add(_enumLabel(tile.decorationType));
    }

    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _getSelectedTileDetails(int index, Tile tile) {
    final theme = Theme.of(context);
    final isEmpty = tile.isEmpty();
    final summary = _tileScoringSummary(tile);
    final invalids = TilePlacement.invalidReasons(_castleTiles, index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TileWidget(
            tile,
            scale: tile.isThroneRoom() ? 0.35 : 0.5,
            showOutline: true,
            showInvalidBadge: invalids.isNotEmpty,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEmpty ? 'Empty cell' : tile.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    tileTypeDisplayName(tile.tileType),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (summary != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ] else
                  Text(
                    _canAddAt(index)
                        ? 'Tap Add to place a tile'
                        : 'Cannot place a tile here',
                    style: theme.textTheme.bodySmall,
                  ),
                for (final reason in invalids) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Invalid: ${TilePlacement.describeInvalidReason(reason)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getSelectionActionBar() {
    final index = _selectedIndex;
    if (index == null || index < 0 || index >= _castleTiles.items.length) {
      return const SizedBox.shrink();
    }

    final tile = _castleTiles.items[index];
    final isEmpty = tile.isEmpty();
    final isThrone = tile.tileType == TileType.ThroneRoom;
    final isMovable = tile.isMovable();
    final canAdd = isEmpty && _canAddAt(index);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _getSelectedTileDetails(index, tile),
          Row(
            children: [
              if (canAdd)
                FloatingActionButton.extended(
                  heroTag: 'add_tile',
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  onPressed: _openTilePickerForSelected,
                ),
              if (isMovable) ...[
                FloatingActionButton.extended(
                  heroTag: 'update_tile',
                  icon: const Icon(Icons.edit),
                  label: const Text('Update'),
                  onPressed: _openTilePickerForSelected,
                ),
                const SizedBox(width: 8),
                FloatingActionButton.extended(
                  heroTag: 'remove_tile',
                  icon: const Icon(Icons.delete),
                  label: const Text('Remove'),
                  onPressed: _removeSelectedTile,
                ),
              ],
              if (isThrone)
                FloatingActionButton.extended(
                  heroTag: 'update_tr_selected',
                  icon: const Icon(Icons.edit),
                  label: const Text('Update'),
                  onPressed: _showThroneRoomPicker,
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Clear selection',
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedIndex = null;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getTokenStrip() {
    final theme = Theme.of(context);
    final selected = _selectedTokenIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bonus & Royal attendants',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: TileWidget.defaultTileWidthHeight * 0.65 + 8,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tokenTiles.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == _tokenTiles.length) {
                  return InkWell(
                    onTap: () => _openTokenPicker(),
                    child: Container(
                      width: TileWidget.defaultTileWidthHeight * 0.65,
                      height: TileWidget.defaultTileWidthHeight * 0.65,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        color: Colors.black26,
                      ),
                      child: const Icon(Icons.add, color: Colors.white70),
                    ),
                  );
                }

                final tile = _tokenTiles[index];
                final isSelected = selected == index;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedTokenIndex = index;
                      _selectedIndex = null;
                    });
                  },
                  child: Container(
                    foregroundDecoration: isSelected
                        ? BoxDecoration(
                            border: Border.all(
                              width: 3,
                              color: Colors.lightBlueAccent,
                            ),
                          )
                        : null,
                    child: TileWidget(tile, scale: 0.65, showOutline: true),
                  ),
                );
              },
            ),
          ),
          if (selected != null &&
              selected >= 0 &&
              selected < _tokenTiles.length) ...[
            const SizedBox(height: 6),
            _getSelectedTokenDetails(_tokenTiles[selected], selected),
          ],
        ],
      ),
    );
  }

  Widget _getSelectedTokenDetails(Tile tile, int selected) {
    final theme = Theme.of(context);
    final title = TokenTileGrid.displayName(tile);
    final typeLabel = tileTypeDisplayName(tile.tileType);
    final scoring = TokenTileGrid.scoringDescription(tile);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TileWidget(tile, scale: 0.5, showOutline: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(typeLabel, style: theme.textTheme.bodySmall),
              if (scoring.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  scoring,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              Row(
                children: [
                  TextButton(
                    onPressed: () => _openTokenPicker(replaceIndex: selected),
                    child: const Text('Update'),
                  ),
                  TextButton(
                    onPressed: _removeSelectedToken,
                    child: const Text('Remove'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Clear selection',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedTokenIndex = null;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _getBody() => ExpandableGridMapView<Tile>(
        gridList: _castleTiles,
        getEmpty: () => Empty(),
        canDragItem: (item) => item.isMovable(),
        isOccupied: _isOccupied,
        canDropOnItem: _canDropTarget,
        canAcceptDraggedItem: _canAcceptDraggedTile,
        builder: (context, index, item) => TileWidget(
          item,
          showOutline: true,
          showInvalidBadge:
              TilePlacement.hasInvalidPlacement(_castleTiles, index),
        ),
        feedback: (context, index, item) => TileWidget(
          item,
          showInvalidBadge:
              TilePlacement.hasInvalidPlacement(_castleTiles, index),
        ),
        wrapperOnDropHover: (item, built) => Container(
          child: built,
          foregroundDecoration: BoxDecoration(
            border: Border.all(
              width: 15,
              color: Colors.lightBlueAccent,
            ),
          ),
        ),
        selectedIndex: _selectedIndex,
        onTapItem: _onTapCell,
        onDropOnItem: _applyGridDrop,
        onDragItem: (int index) {
          var copy = _castleTiles;
          var item = copy.items[index];
          if (item.tileType == TileType.ThroneRoom) {
            copy.items[index] = Empty();
            copy.items[index + 1] = Empty();
          } else {
            copy.items[index] = Empty();
          }

          setState(() {
            _castleTiles = copy;
            _syncCastleFromParts();
            _draggingTile = null;
            _gridDragSourceIndex = index;
            _selectedIndex = null;
            _selectedTokenIndex = null;
          });
        },
        onExpandCollapse: (result) {
          _updateCastle(result);
          setState(() {
            _refreshAvailableTiles();
          });
        },
        onDragCancelled: (int index, Tile item) {
          var copy = _castleTiles;
          if (item.tileType == TileType.ThroneRoom) {
            copy.items[index] = item;
            if (index + 1 >= copy.items.length) {
              copy.items.add(Placeholder());
            } else {
              copy.items[index + 1] = Placeholder();
            }
          } else {
            copy.items[index] = item;
          }

          final normalized = _normalize(copy);
          setState(() {
            _castleTiles = normalized.grid;
            _syncCastleFromParts();
            _draggingTile = null;
            _gridDragSourceIndex = null;
          });
        },
      );

  List<Tile> _getFilteredTiles() {
    String text = _filterText.toLowerCase();
    List<Tile> filtered = _allTiles
        .where((element) => element.name.toLowerCase().contains(text))
        .toList();
    return filtered;
  }

  List<Widget> _getFilteredListViewChildren() {
    var filtered = _getFilteredTiles();
    return filtered
        .map((tile) => LongPressDraggable(
              delay: DragAndDropGrid.dragDelay,
              data: tile,
              feedback: TileWidget(tile),
              child: TileWidget(tile),
              childWhenDragging: TileWidget(tile),
              onDragStarted: () {
                log('alltiles length ${_allTiles.length}');
                var copy = _allTiles;
                int index = copy.indexWhere((element) => element.id == tile.id);
                log('OnDragStarted from list view: $index');
                copy.removeAt(index);
                log('copy length ${copy.length}');
                setState(() {
                  _allTiles = copy;
                  _draggingTile = new DraggedTileInfo(index, tile);
                });
              },
              onDraggableCanceled: (velocity, offset) {
                log('OnDragCancelled from list view: ${_draggingTile!.index}');
                var copy = _allTiles;
                copy.insert(_draggingTile!.index, _draggingTile!.tile);
                setState(() {
                  _draggingTile = null;
                  _allTiles = copy;
                });
              },
            ))
        .toList();
  }

  Widget _getChangeThroneRoomButton() => FloatingActionButton.extended(
        heroTag: 'tr',
        label: Text('Set Throneroom'),
        onPressed: _showThroneRoomPicker,
      );

  Widget _getSaveButton() => FloatingActionButton.extended(
        heroTag: 'save',
        icon: Icon(Icons.save),
        label: Text('Save'),
        onPressed: () async {
          var castle = Castle(_mergedGrid());
          if (widget.updateCastleCallback != null &&
              widget.existingCastle != null) {
            castle.hiveCastle = widget.existingCastle!.hiveCastle;
            castle.title = widget.existingCastle!.title;
            await widget.updateCastleCallback!(castle);
            await Analytics.logCastleSavedFromCastleBuilder(
                widget.numPicturesTaken);
            Navigator.pop(context);
            return;
          }

          if (widget.addCastleCallback != null) {
            await widget.addCastleCallback!(
                castle, widget.imagePath ?? '', widget.numPicturesTaken);
            await Analytics.logCastleSavedFromCastleBuilder(
                widget.numPicturesTaken);
            Navigator.pop(context);
          }
        },
      );

  Widget _getBottomButtonRow() => Row(
        children: [
          FloatingActionButton.extended(
            heroTag: 'score',
            label: Text('Score'),
            icon: Icon(Icons.view_list),
            onPressed: () {
              _syncCastleFromParts();
              _castle.scoreCastle([]);
              NavigationHelper.goToCastleScreen(context, _castle,
                  onlyShowScoreCard: true);
            },
          ),
          Flexible(
            child: Container(),
          ),
          _getChangeThroneRoomButton(),
          Flexible(
            child: Container(),
          ),
          _getSaveButton(),
        ],
      );

  Widget _getBottomSheet() => Column(
        children: [
          _getSelectionActionBar(),
          FilteredDragAndDropListView<Tile>(
            hintText: 'Filter by tile name',
            onAcceptWithDetails:
                (DragTargetDetails details, ScrollController controller) {
              if (_draggingTile != null) {
                log(
                    'OnAcceptWithDetails from listview drag: ${details.offset}');
                var copy = _allTiles;
                copy.insert(_draggingTile!.index, _draggingTile!.tile);
                setState(() {
                  _draggingTile = null;
                  _allTiles = copy;
                });
              } else {
                log('OnAcceptWithDetails from grid: ${details.offset}');

                int scrollOffsetIndex =
                    controller.offset ~/ TileWidget.defaultTileWidthHeight;
                int dragOffsetIndex =
                    details.offset.dx ~/ TileWidget.defaultTileWidthHeight + 1;
                int roughIndex =
                    min(_allTiles.length, scrollOffsetIndex + dragOffsetIndex);

                var copy = _allTiles;
                copy.insert(roughIndex, details.data);
                final normalized = _normalize(_castleTiles);
                setState(() {
                  _allTiles = copy;
                  _castleTiles = normalized.grid;
                  _syncCastleFromParts();
                  _gridDragSourceIndex = null;
                });
              }
            },
            onClearPressed: () {
              setState(() {
                _filterText = '';
              });
            },
            onTextChanged: (String value) {
              setState(() {
                _filterText = value;
              });
            },
            children: _getFilteredListViewChildren(),
          ),
          ButtonPadding(),
          _getBottomButtonRow(),
          ButtonPadding(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.updateCastleCallback != null;
    final segments = <String>[
      widget.gameTitle ?? 'Game',
      if (editing) widget.existingCastle?.title ?? 'Castle',
      editing ? 'Edit' : 'Build',
    ];

    return Scaffold(
      appBar: AppBar(
        title: FlowBreadcrumb(
          segments: segments,
          onFirstSegmentTap: () => Navigator.of(context).pop(),
        ),
      ),
      body: BackgroundContainer(
        child: Column(
          children: [
            _getTokenStrip(),
            Expanded(
              child: _getBody(),
            ),
            Align(
              alignment: FractionalOffset.bottomCenter,
              child: _getBottomSheet(),
            ),
          ],
        ),
      ),
    );
  }
}
