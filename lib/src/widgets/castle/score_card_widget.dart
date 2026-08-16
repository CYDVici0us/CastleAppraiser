import 'dart:math' as math;

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/asset_helper.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/widgets/tile/tile_type_widget.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart';

class ScoreCardWidget extends StatelessWidget {
  final Castle castle;

  ScoreCardWidget(this.castle);

  static const double _horizontalPadding = 16;
  static const double _totalColumnWidth = 64;
  static const double _tileGap = 6;
  static const double _categoryGap = 8;
  static const double _totalGap = 12;
  static const double _rowGap = 8;
  static const double _countLabelHeight = 22;
  /// Score tiles sized to fit this many across.
  static const int _maxFitAcross = 3;
  /// Category leading icon is half the score-tile size.
  static const double _categorySizeFactor = 0.5;

  int _getTotal(Map<TileId, int> tiles) {
    var total = 0;
    for (final value in tiles.values) {
      total += value;
    }
    return total;
  }

  Widget _countLabel(String text, TextStyle? style) => SizedBox(
        height: _countLabelHeight,
        child: Center(
          child: Text(text, style: style),
        ),
      );

  /// Display width for a score-card tile at [scale] (height = square tile size).
  double _tileDisplayWidth(Tile tile, double scale) {
    final height = TileWidget.defaultTileWidthHeight * scale;
    if (tile.isThroneRoom()) {
      return height * 2;
    }
    if (tile.isBonusCard()) {
      final size =
          AssetHelper().tileSizeInImageFromTileType(TileType.BonusCard);
      return height * (size.dx / size.dy);
    }
    return height;
  }

  Widget _tileColumn({
    required TileId id,
    required int score,
    required double scale,
    required TextStyle? countStyle,
  }) {
    final tile = TileHelper().getTileById(id);
    final width = _tileDisplayWidth(tile, scale);
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _countLabel('$score', countStyle),
          const SizedBox(height: 2),
          TileWidget(
            tile,
            scale: scale,
          ),
        ],
      ),
    );
  }

  Widget _tileLine({
    required List<MapEntry<TileId, int>> entries,
    required double scale,
    required TextStyle? countStyle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: _tileGap),
          _tileColumn(
            id: entries[i].key,
            score: entries[i].value,
            scale: scale,
            countStyle: countStyle,
          ),
        ],
      ],
    );
  }

  Widget _categoryLeading({
    required Widget category,
    required double tileScale,
  }) {
    final tileSize = TileWidget.defaultTileWidthHeight * tileScale;
    final categorySize = tileSize * _categorySizeFactor;

    return SizedBox(
      width: categorySize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _countLabel('', null),
          const SizedBox(height: 2),
          SizedBox(
            width: categorySize,
            height: categorySize,
            child: category,
          ),
        ],
      ),
    );
  }

  List<List<MapEntry<TileId, int>>> _chunkEntries(
    List<MapEntry<TileId, int>> entries,
    int perLine,
  ) {
    if (entries.isEmpty) return const [];
    if (perLine <= 0) return [entries];
    final lines = <List<MapEntry<TileId, int>>>[];
    for (var i = 0; i < entries.length; i += perLine) {
      lines.add(
        entries.sublist(i, math.min(i + perLine, entries.length)),
      );
    }
    return lines;
  }

  Widget _scoreCardRow({
    required Map<TileId, int> tiles,
    required TextTheme textTheme,
    required double scale,
    Widget Function(double scale)? categoryBuilder,
    /// When true (specials), leave empty space matching the category icon so
    /// tiles line up under primary category tiles.
    bool alignToCategoryTiles = false,
  }) {
    final countStyle = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final totalStyle = textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.0,
    );
    final entries = tiles.entries.toList();
    final tileSize = TileWidget.defaultTileWidthHeight * scale;
    final categorySize = tileSize * _categorySizeFactor;
    final lines = _chunkEntries(entries, _maxFitAcross);
    final lineCount = math.max(lines.length, 1);
    final totalAlignHeight = lineCount <= 1
        ? tileSize
        : tileSize * lineCount + _rowGap * (lineCount - 1);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categoryBuilder != null) ...[
            _categoryLeading(
              category: categoryBuilder(scale * _categorySizeFactor),
              tileScale: scale,
            ),
            const SizedBox(width: _categoryGap),
          ] else if (alignToCategoryTiles) ...[
            SizedBox(width: categorySize),
            const SizedBox(width: _categoryGap),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0) const SizedBox(height: _rowGap),
                    _tileLine(
                      entries: lines[i],
                      scale: scale,
                      countStyle: countStyle,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: _totalGap),
          SizedBox(
            width: _totalColumnWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _countLabel('', null),
                const SizedBox(height: 2),
                SizedBox(
                  height: totalAlignHeight,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_getTotal(tiles)}',
                      style: totalStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<({Widget Function(double scale) category, Map<TileId, int> tiles})>
      _buildPrimaryRows(ScoreCard scoreCard) {
    return [
      (
        category: (s) => TileTypeWidget(TileType.Food, scale: s),
        tiles: scoreCard.food,
      ),
      (
        category: (s) => TileTypeWidget(TileType.Living, scale: s),
        tiles: scoreCard.living,
      ),
      (
        category: (s) => TileTypeWidget(TileType.Utility, scale: s),
        tiles: scoreCard.utility,
      ),
      (
        category: (s) => TileTypeWidget(TileType.Outdoor, scale: s),
        tiles: scoreCard.outDoor,
      ),
      (
        category: (s) => TileTypeWidget(TileType.Sleeping, scale: s),
        tiles: scoreCard.sleeping,
      ),
      (
        category: (s) => TileTypeWidget(TileType.Corridor, scale: s),
        tiles: scoreCard.corridor,
      ),
      (
        category: (s) => TileTypeWidget(TileType.Downstairs, scale: s),
        tiles: scoreCard.downstairs,
      ),
      (
        category: (s) => TileTypeWidget(TileType.Secret, scale: s),
        tiles: scoreCard.secret,
      ),
      (
        category: (s) => TileTypeWidget(TileType.Activity, scale: s),
        tiles: scoreCard.activity,
      ),
    ].where((row) => row.tiles.isNotEmpty).toList();
  }

  /// Specialty rooms only — throne / bonus / attendants live in Points per tile.
  List<Map<TileId, int>> _buildSpecialRows(ScoreCard scoreCard) {
    return [
      scoreCard.ballroom,
      scoreCard.fountain,
      scoreCard.tower,
      scoreCard.grandFoyer,
    ].where((tiles) => tiles.isNotEmpty).toList();
  }

  /// Fixed scale: always fit [_maxFitAcross] tiles (+ half-size category icon).
  /// Count does not grow/shrink tile size — extra tiles wrap.
  double _computeTileScale(double maxWidth) {
    final reserved = 2 * _horizontalPadding +
        _totalColumnWidth +
        _totalGap +
        _categoryGap;
    final gaps = _tileGap * (_maxFitAcross - 1);
    final tileSize = ((maxWidth - reserved - gaps) /
            (_categorySizeFactor + _maxFitAcross))
        .clamp(28.0, 100.0);
    return tileSize / TileWidget.defaultTileWidthHeight;
  }

  @override
  Widget build(BuildContext context) {
    castle.getScore();
    final scoreCard = castle.castleScoreCard!;
    final textTheme = Theme.of(context).textTheme;
    final primaryRows = _buildPrimaryRows(scoreCard);
    final specialRows = _buildSpecialRows(scoreCard);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = _computeTileScale(constraints.maxWidth);

          return Column(
            children: [
              for (final row in primaryRows)
                _scoreCardRow(
                  categoryBuilder: row.category,
                  tiles: row.tiles,
                  textTheme: textTheme,
                  scale: scale,
                ),
              for (final tiles in specialRows)
                _scoreCardRow(
                  tiles: tiles,
                  textTheme: textTheme,
                  scale: scale,
                  alignToCategoryTiles: true,
                ),
            ],
          );
        },
      ),
    );
  }
}
