import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/tile_placement.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart';

class CastleTilesGrid extends StatelessWidget {

  final GridList<Tile> castleTiles;
  final double scale;
  final bool scaleWithScreen;
  final double scalePercentScreenWidth;
  CastleTilesGrid(this.castleTiles, {
    this.scale=1, 
    this.scaleWithScreen=true,
    this.scalePercentScreenWidth=0
  });

  double _getScale(BuildContext context) {

    if (scalePercentScreenWidth != 0) {
      // we want the whole castle to be as wide as scalePercentScreenWidth of the screen
      // this can make the cards taller if castles are taller than they are wide 
      return ((MediaQuery.of(context).size.width * scalePercentScreenWidth) / castleTiles.maxDimension) / TileWidget.defaultTileWidthHeight;
    }

    if (scaleWithScreen) {
      return (MediaQuery.of(context).size.width / castleTiles.width) / TileWidget.defaultTileWidthHeight;
    }

    return scale;
  }

  @override
  Widget build(BuildContext context) {

    // if scaleWithScreen is true, ignore scale
    double scaleToUse = _getScale(context);
    final cellSize = TileWidget.defaultTileWidthHeight * scaleToUse;

    List<Widget> columnChildren = [];
    List<Widget> widgetList = [];

    for (int i = 0; i < castleTiles.items.length; i++) {
      if (i%castleTiles.width == 0 && i != 0) {
        columnChildren.add(Row(children: widgetList));
        widgetList = [];
      }

      final tile = castleTiles.items[i];
      final tileWidget = TileWidget(
        tile,
        scale: scaleToUse,
        emptyColor: Colors.transparent,
        showInvalidBadge:
            TilePlacement.hasInvalidPlacement(castleTiles, i),
      );

      // Keep grid column width uniform; bonus cards are narrower than a cell.
      if (tile.isBonusCard() || tile.isRoyalAttendant()) {
        widgetList.add(SizedBox(
          width: cellSize,
          height: cellSize,
          child: Align(
            alignment: Alignment.center,
            child: tileWidget,
          ),
        ));
      } else {
        widgetList.add(tileWidget);
      }
    }

    columnChildren.add(Row(children:widgetList));

    return Column(
      children: columnChildren
    );
  }

  
}
