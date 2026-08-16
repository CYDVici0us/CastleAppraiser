import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/asset_helper.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart';

class TileTypeWidget extends StatelessWidget {
  final TileType type;
  final double scale;

  TileTypeWidget(this.type, {this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final size = TileWidget.defaultTileWidthHeight * scale;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        AssetHelper().getScoringCategoryImageFromTileType(type),
        height: size,
        width: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
