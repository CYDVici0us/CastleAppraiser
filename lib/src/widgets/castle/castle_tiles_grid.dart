import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/cell_guess_info.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/tile_placement.dart';
import 'package:btcc/src/widgets/castle/guess_confidence_overlay.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart';

/// Castle grid with optional ML confidence overlays for Confirm review.
class CastleTilesGrid extends StatelessWidget {
  final GridList<Tile> castleTiles;
  final double scale;
  final bool scaleWithScreen;
  final double scalePercentScreenWidth;
  final Map<int, CellGuessInfo>? cellGuesses;
  final void Function(int index)? onCellTap;
  final int? highlightIndex;

  const CastleTilesGrid(
    this.castleTiles, {
    super.key,
    this.scale = 1,
    this.scaleWithScreen = true,
    this.scalePercentScreenWidth = 0,
    this.cellGuesses,
    this.onCellTap,
    this.highlightIndex,
  });

  double _getScale(BuildContext context) {
    if (scalePercentScreenWidth != 0) {
      return ((MediaQuery.of(context).size.width * scalePercentScreenWidth) /
              castleTiles.maxDimension) /
          TileWidget.defaultTileWidthHeight;
    }
    if (scaleWithScreen) {
      return (MediaQuery.of(context).size.width / castleTiles.width) /
          TileWidget.defaultTileWidthHeight;
    }
    return scale;
  }

  @override
  Widget build(BuildContext context) {
    final scaleToUse = _getScale(context);
    final cellSize = TileWidget.defaultTileWidthHeight * scaleToUse;
    final columnChildren = <Widget>[];
    var widgetList = <Widget>[];

    for (var i = 0; i < castleTiles.items.length; i++) {
      if (i % castleTiles.width == 0 && i != 0) {
        columnChildren.add(Row(
          mainAxisSize: MainAxisSize.min,
          children: widgetList,
        ));
        widgetList = [];
      }

      final raw = castleTiles.items[i];
      final gapFillingToken = TilePlacement.isGapFillingToken(castleTiles, i);
      final tile = gapFillingToken ? Empty() : raw;
      final info = cellGuesses?[i];
      final invalid = gapFillingToken ||
          TilePlacement.hasInvalidPlacement(castleTiles, i);
      final isHighlight = highlightIndex == i;

      Widget tileWidget = TileWidget(
        tile,
        scale: scaleToUse,
        emptyColor: Colors.transparent,
        showInvalidBadge: invalid,
      );

      tileWidget = GuessConfidenceOverlay(
        info: info,
        tile: tile,
        scale: scaleToUse,
        highlight: isHighlight,
        child: tileWidget,
      );

      if (onCellTap != null && !tile.isPlaceholder()) {
        tileWidget = GestureDetector(
          onTap: () => onCellTap!(i),
          child: tileWidget,
        );
      }

      if (!gapFillingToken &&
          (tile.isBonusCard() || tile.isRoyalAttendant())) {
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

    columnChildren.add(Row(
      mainAxisSize: MainAxisSize.min,
      children: widgetList,
    ));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: columnChildren,
    );
  }
}
