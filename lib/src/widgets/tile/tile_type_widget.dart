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
    // Rounded square (not a circle).
    final radius = (size * 0.22).clamp(2.0, 10.0);
    final inset = (size * 0.1).clamp(1.5, 6.0);
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: Image.asset(
            AssetHelper().getScoringCategoryImageFromTileType(type),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
