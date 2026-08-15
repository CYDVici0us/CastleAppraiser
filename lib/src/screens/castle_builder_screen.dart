import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/analytics/analytics.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/builder/expandable_grid_map_view.dart';
import 'package:btcc/src/widgets/builder/filtered_drag_and_drop_list_view.dart';
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

  @override
  void initState() {
    super.initState();

    _textEditingController = new TextEditingController();
    _castleTiles = widget.castleTiles;
    _allTiles = TileHelper().getListOfTilesExcludingTilesAndTrs(_castleTiles.items);
    _castle = new Castle(_castleTiles);
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  void _updateCastle(GridList<Tile> copy) {
    setState(() {
      _castleTiles = copy;
      _castle = new Castle(_castleTiles);
      _draggingTile = null;
    });
  }


  Widget _getBody() => ExpandableGridMapView<Tile>(
    gridList: _castleTiles,
    getEmpty: () => Empty(),
    canDragItem: (item) => item.isMovable(),
    canDropOnItem: (item) => item.isEmpty(),
    builder: (_, item) => TileWidget(item, showOutline: true,),
    feedback: (_, item) => TileWidget(item),
    wrapperOnDropHover: (item, built) => Container(
      child: built,
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          width: 15,
          color: item.isEmpty() ? Colors.redAccent : Colors.transparent
        ),
      ),
    ),
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
    },
    onExpandCollapse: (result) {
      _updateCastle(result);
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

      _updateCastle(copy);
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
    onPressed: () {
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