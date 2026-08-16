import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/asset_helper.dart';
import 'package:flutter/material.dart';

import 'atlas_image.dart';

class TileWidget extends StatelessWidget {
  final Tile tile;
  final double scale;
  final double tileWidth;
  final Color emptyColor;
  final bool showOutline;
  final bool showInvalidBadge;
  TileWidget(this.tile, {
    this.scale = 1,
    this.tileWidth = defaultTileWidthHeight,
    this.emptyColor = Colors.black,
    this.showOutline = false,
    this.showInvalidBadge = false,
  });

  static const double defaultTileWidthHeight = 100;
  static const Color _tokenBorderColor = Color(0xFF9E9E9E);

  bool get _isTokenTile => tile.isBonusCard() || tile.isRoyalAttendant();

  double _getTileWidth() {
    if (tileWidth != defaultTileWidthHeight) {
      return tileWidth;
    }

    if (tile.tileType == TileType.ThroneRoom) {
      return defaultTileWidthHeight * 2 * scale;
    }
    if (tile.tileType == TileType.Placeholder) {
      return 0;
    }
    if (tile.isBonusCard()) {
      return _bonusCardDisplayWidth(defaultTileWidthHeight * scale);
    }

    return defaultTileWidthHeight * scale;
  }

  /// Bonus art aspect (atlas cell width / height).
  double _bonusCardDisplayWidth(double height) {
    final size = AssetHelper().tileSizeInImageFromTileType(TileType.BonusCard);
    return height * (size.dx / size.dy);
  }

  Widget _buildTokenTile() {
    final height = defaultTileWidthHeight * scale;
    final src = tile.getRect();
    final width = tile.isBonusCard()
        ? height * (src.width / src.height)
        : height;

    // Bonus cards: show full printed art (including red edge). No clip / no
    // overlay border that would cover that edge.
    if (tile.isBonusCard()) {
      return SizedBox(
        height: height,
        width: width,
        child: AtlasImage(
          height: height,
          width: width,
          imagePath: tile.getFullAssetPath(),
          rect: src,
          scaleFactor: height / src.height,
        ),
      );
    }

    // Royal attendants: square token with rounded corners clipped to the
    // border so atlas art cannot spill past the frame.
    final radius = (6.0 * scale).clamp(4.0, 10.0);
    const borderWidth = 1.0;
    final innerRadius = (radius - borderWidth).clamp(0.0, radius);
    final innerSize = height - 2 * borderWidth;
    final innerScale = innerSize / src.height;

    return SizedBox(
      height: height,
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            width: borderWidth,
            color: _tokenBorderColor,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(borderWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(innerRadius),
            clipBehavior: Clip.antiAlias,
            child: AtlasImage(
              height: innerSize,
              width: innerSize,
              imagePath: tile.getFullAssetPath(),
              rect: src,
              scaleFactor: innerScale,
            ),
          ),
        ),
      ),
    );
  }

  Widget _withInvalidBadge(Widget child) {
    if (!showInvalidBadge) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 2 * scale,
          right: 2 * scale,
          child: Container(
            padding: EdgeInsets.all(2 * scale),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 18 * scale,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (tile.tileType == TileType.Placeholder) {
      return Container();
    }

    if (_isTokenTile && tile.localImageLocation.contains('Atlas')) {
      return _withInvalidBadge(_buildTokenTile());
    }

    Widget child;

    if (tile.localImageLocation.contains('Atlas')) {
      child = AtlasImage(
        height: defaultTileWidthHeight * scale,
        width: _getTileWidth(),
        imagePath: tile.getFullAssetPath(),
        rect: tile.getRect(),
        scaleFactor:
            scale * AssetHelper().getScaleFactorFromTileType(tile.tileType),
      );
    } else if (tile.tileType == TileType.ThroneRoom) {
      child = Image(
        image: AssetImage(tile.getFullAssetPath()),
        fit: BoxFit.fill,
      );
    } else if (tile.tileType == TileType.Empty) {
      child = Container(
        child: Material(
          color: showInvalidBadge
              ? const Color.fromARGB(255, 120, 40, 40)
              : emptyColor,
        ),
        foregroundDecoration: BoxDecoration(
          border: Border.all(
            width: showInvalidBadge ? 2 : 1,
            color: showInvalidBadge
                ? Colors.redAccent
                : (showOutline ? Colors.grey : Colors.transparent),
          ),
        ),
      );
    } else {
      child = Image(
        image: AssetImage(tile.getFullAssetPath()),
        fit: BoxFit.fill,
      );
    }

    return Container(
      height: defaultTileWidthHeight * scale,
      width: _getTileWidth(),
      child: _withInvalidBadge(child),
    );
  }
}
