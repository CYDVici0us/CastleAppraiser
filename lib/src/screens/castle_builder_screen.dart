import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/analytics/analytics.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/tile_placement.dart';
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
    this.numPicturesTaken=0,
    this.gameTitle,
  });

  @override
  _CastleBuilderScreenState createState() => new _CastleBuilderScreenState();
}

class _CastleBuilderScreenState extends State<CastleBuilderScreen>{

  late TextEditingController _textEditingController;

  String _filterText = '';
  List<Tile> _allTiles = [];
  late GridList<Tile> _castleTiles;
  DraggedTileInfo? _draggingTile;
  late Castle _castle;
  int? _selectedIndex;

  static bool _isOccupied(Tile tile) => !tile.isEmpty();

  @override
  void initState() {
    super.initState();

    _textEditingController = new TextEditingController();
    final normalized = GridListNormalizer.normalizePerimeter(
      widget.castleTiles,
      isOccupied: _isOccupied,
      getEmpty: () => Empty(),
    );
    _castleTiles = normalized.grid;
    _allTiles = TileHelper().getListOfTilesExcludingTilesAndTrs(_castleTiles.items);
    _castle = new Castle(_castleTiles);
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  bool _canAddAt(int index) =>
      GridListNormalizer.canPlaceAdjacent(
        _castleTiles,
        index,
        isOccupied: _isOccupied,
      ) &&
      !TilePlacement.isDirectlyAboveOutdoor(_castleTiles, index);

  bool _canPlaceTileAt(int index, Tile tile, {bool allowAboveOutdoor = false}) =>
      TilePlacement.canPlaceTile(
        _castleTiles,
        index,
        tile,
        allowAboveOutdoor: allowAboveOutdoor,
      );

  GridNormalizeResult<Tile> _normalize(GridList<Tile> grid) =>
      GridListNormalizer.normalizePerimeter(
        grid,
        isOccupied: _isOccupied,
        getEmpty: () => Empty(),
      );

  void _updateCastle(GridList<Tile> copy) {
    setState(() {
      _castleTiles = copy;
      _castle = new Castle(_castleTiles);
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
    });
  }

  Future<void> _openTilePickerForSelected() async {
    final index = _selectedIndex;
    if (index == null) return;

    final chosen = await showTilePickerDialog(
      context: context,
      availableTiles: List<Tile>.from(_allTiles),
    );
    if (chosen == null || !mounted) return;

    _placeTileAt(index, chosen);
  }

  void _placeTileAt(int index, Tile tile) {
    final existing = _castleTiles.items[index];
    // Add only onto adjacent empties; Update may keep camera placements above Outdoor.
    if (existing.isEmpty()) {
      if (!_canAddAt(index) || !_canPlaceTileAt(index, tile)) {
        return;
      }
    } else if (!_canPlaceTileAt(index, tile, allowAboveOutdoor: true)) {
      return;
    }

    var copy = _castleTiles;
    copy.items[index] = tile;
    final normalized = _normalize(copy);
    final mapped = normalized.mapIndex(index);

    setState(() {
      _castleTiles = normalized.grid;
      _castle = Castle(_castleTiles);
      _draggingTile = null;
      _allTiles = TileHelper().getListOfTilesExcludingTilesAndTrs(_castleTiles.items);
      _selectedIndex = mapped;
    });
  }

  void _removeSelectedTile() {
    final index = _selectedIndex;
    if (index == null) return;
    final tile = _castleTiles.items[index];
    if (!tile.isMovable()) return;

    final copy = _castleTiles;
    copy.items[index] = Empty();
    final normalized = _normalize(copy);
    final mapped = normalized.mapIndex(index);

    setState(() {
      _castleTiles = normalized.grid;
      _castle = Castle(_castleTiles);
      _draggingTile = null;
      _allTiles = TileHelper().getListOfTilesExcludingTilesAndTrs(_castleTiles.items);
      _selectedIndex = mapped;
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
                      int i = copy.items.indexWhere((element) => element.tileType == TileType.ThroneRoom);
                      copy.items.replaceRange(i, i+1, [trs[index]]);
                      _updateCastle(copy);
                      Navigator.pop(ctx);
                    },
                  )
                )
              )
            )
          ],
        ),
      )
    );
  }

  static String _enumLabel(Object value) =>
      value.toString().split('.').last;

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
    final invalidAboveOutdoor =
        TilePlacement.hasInvalidAboveOutdoorPlacement(_castleTiles, index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isEmpty)
            TileWidget(
              tile,
              scale: tile.isThroneRoom() ? 0.35 : 0.5,
              showOutline: true,
              showInvalidBadge: invalidAboveOutdoor,
            ),
          if (!isEmpty) const SizedBox(width: 12),
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
                if (invalidAboveOutdoor) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Invalid placement: cannot sit above Outdoor',
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

  Widget _getBody() => ExpandableGridMapView<Tile>(
    gridList: _castleTiles,
    getEmpty: () => Empty(),
    canDragItem: (item) => item.isMovable(),
    isOccupied: _isOccupied,
    canDropOnItem: (index, item) =>
        item.isEmpty() && _canAddAt(index),
    canAcceptDraggedItem: (index, tile) => _canPlaceTileAt(index, tile),
    builder: (context, index, item) => TileWidget(
      item,
      showOutline: true,
      showInvalidBadge:
          TilePlacement.hasInvalidAboveOutdoorPlacement(_castleTiles, index),
    ),
    feedback: (context, index, item) => TileWidget(
      item,
      showInvalidBadge:
          TilePlacement.hasInvalidAboveOutdoorPlacement(_castleTiles, index),
    ),
    wrapperOnDropHover: (item, built) => Container(
      child: built,
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          width: 15,
          color: item.isEmpty() ? Colors.redAccent : Colors.transparent
        ),
      ),
    ),
    selectedIndex: _selectedIndex,
    onTapItem: _onTapCell,
    onDropOnItem: (int index, Tile item) {
      //print(item.toJson());
      var copy = _castleTiles;
      if (item.tileType == TileType.ThroneRoom) {
        copy.items[index] = item;
        if (index+1 >= copy.items.length) {
          copy.items.add(new Placeholder());
        }
        else {
          copy.items[index+1] = new Placeholder();
        }
      }
      else {
        copy.items[index] = item;
      }

      _updateCastle(copy);
      setState(() {
        _allTiles = TileHelper().getListOfTilesExcludingTilesAndTrs(_castleTiles.items);
        _selectedIndex = null;
      });
    },
    onDragItem: (int index) {
      //print(_castleTiles.items[index].toJson());
      var copy = _castleTiles;
      var item = copy.items[index];
      if (item.tileType == TileType.ThroneRoom) {
        copy.items[index] = Empty();
        copy.items[index+1] = Empty();
      }
      else {
        copy.items[index] = Empty();
      }

      _updateCastle(copy);
      setState(() {
        _selectedIndex = null;
      });
    },
    onExpandCollapse: (result) {
      _updateCastle(result);
      setState(() {
        _allTiles = TileHelper().getListOfTilesExcludingTilesAndTrs(_castleTiles.items);
      });
    },
    onDragCancelled: (int index, Tile item) {
      // same as drop on item, restore it to its old location
      //print(item.toJson());
      var copy = _castleTiles;
      if (item.tileType == TileType.ThroneRoom) {
        copy.items[index] = item;
        if (index+1 >= copy.items.length) {
          copy.items.add(new Placeholder());
        }
        else {
          copy.items[index+1] = new Placeholder();
        }
      }
      else {
        copy.items[index] = item;
      }

      final normalized = _normalize(copy);
      _updateCastle(normalized.grid);
    },
  );

  List<Tile> _getFilteredTiles() {
    String text = _filterText.toLowerCase();
    List<Tile> filtered = _allTiles.where((element) => 
      element.name.toLowerCase().contains(text)).toList();
    return filtered;
  }

  List<Widget> _getFilteredListViewChildren() {
    var filtered = _getFilteredTiles();
    return filtered.map((tile) => LongPressDraggable(
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
    )).toList();
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
      var castle = Castle(_castleTiles);
      if (widget.updateCastleCallback != null && widget.existingCastle != null) {
        castle.hiveCastle = widget.existingCastle!.hiveCastle;
        castle.title = widget.existingCastle!.title;
        await widget.updateCastleCallback!(castle);
        await Analytics.logCastleSavedFromCastleBuilder(widget.numPicturesTaken);
        Navigator.pop(context);
        return;
      }

      if (widget.addCastleCallback != null) {
        await widget.addCastleCallback!(castle, widget.imagePath ?? '', widget.numPicturesTaken);
        await Analytics.logCastleSavedFromCastleBuilder(widget.numPicturesTaken);
        Navigator.pop(context);
      }
    }
  );

  Widget _getBottomButtonRow() => Row(
    children: [
      FloatingActionButton.extended(
        heroTag: 'score',
        label: Text('Score'),
        icon: Icon(Icons.view_list),
        onPressed: () {
          _castle.scoreCastle([]);
          NavigationHelper.goToCastleScreen(context, _castle, onlyShowScoreCard: true);
        }
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
          onAcceptWithDetails: (DragTargetDetails details, ScrollController controller) {
            // If we're accepting a drag that started from list view
            if (_draggingTile != null) {
              log('OnAcceptWithDetails from listview drag: ${details.offset}');
              var copy = _allTiles;
              copy.insert(_draggingTile!.index, _draggingTile!.tile);
              setState(() {
                _draggingTile = null;
                _allTiles = copy;
              });
            }
            else {
              log('OnAcceptWithDetails from grid: ${details.offset}');

              // Use scrolloffset and drag offset to find which index the tile
              // is dropped over
              int scrollOffsetIndex = controller.offset~/TileWidget.defaultTileWidthHeight;
              int dragOffsetIndex = details.offset.dx~/TileWidget.defaultTileWidthHeight+1;
              int roughIndex = min(_allTiles.length, scrollOffsetIndex+dragOffsetIndex);

              var copy = _allTiles;
              copy.insert(roughIndex, details.data);
              setState(() {
                _allTiles = copy;
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
            Expanded(
              child: _getBody()
            ),
            Align(
              alignment: FractionalOffset.bottomCenter,
              child: _getBottomSheet(),
            ),
          ],
        ),
      )
    );
  }
}
