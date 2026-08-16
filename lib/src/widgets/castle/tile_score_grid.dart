import 'package:auto_size_text/auto_size_text.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/token_tile_grid.dart';
import 'package:btcc/src/widgets/builder/tile_picker_sheet.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart';

class TileScoreGridItem extends StatelessWidget {
  final int score;
  final Tile tile;
  final double scale;

  /// Fixed header: always reserves two name rows so cards don't grow/shrink.
  static const double _nameLineHeight = 18;
  static const double _headerHeight = _nameLineHeight * 2;
  static const double _scoreWidth = 40;

  const TileScoreGridItem({
    super.key,
    required this.score,
    required this.tile,
    required this.scale,
  });

  (String, String) get _nameLines {
    if (tile.isThroneRoom()) {
      return ('Throne Room', '');
    }
    if (tile.isBonusCard()) {
      return ('Bonus Card', TokenTileGrid.displayName(tile));
    }
    if (tile.isRoyalAttendant()) {
      return ('Royal Attendant', TokenTileGrid.displayName(tile));
    }
    if (tile.tileType == TileType.Special) {
      return (
        TokenTileGrid.displayName(tile),
        tileTypeDisplayName(tile.tileType),
      );
    }
    return (tile.name, tileTypeDisplayName(tile.tileType));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (line1, line2) = _nameLines;
    final nameStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.0,
      fontSize: 13,
    );
    final secondaryStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
      height: 1.0,
      fontSize: 12,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: Colors.blueGrey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: _headerHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: _nameLineHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AutoSizeText(
                            line1,
                            maxLines: 1,
                            minFontSize: 9,
                            textAlign: TextAlign.left,
                            style: nameStyle,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: _nameLineHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: line2.isEmpty
                              ? const SizedBox.shrink()
                              : AutoSizeText(
                                  line2,
                                  maxLines: 1,
                                  minFontSize: 9,
                                  textAlign: TextAlign.left,
                                  style: secondaryStyle,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: _scoreWidth,
                  height: _headerHeight,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: AutoSizeText(
                      '$score',
                      maxLines: 1,
                      minFontSize: 14,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                        fontSize: _headerHeight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TileWidget(
            tile,
            showOutline: true,
            scale: scale,
          ),
        ],
      ),
    );
  }
}

class TileScoreGrid extends StatelessWidget {
  static const int _tokenColumns = 3;
  static const int _roomColumns = 2;
  static const double _gap = 8;
  static const double _cardPadding = 8;

  final Castle castle;

  const TileScoreGrid(this.castle);

  @override
  Widget build(BuildContext context) {
    TileScoreEntry? throne;
    final bonuses = <TileScoreEntry>[];
    final attendants = <TileScoreEntry>[];
    final rooms = <TileScoreEntry>[];

    for (final entry in castle.tileScores.entries) {
      final tile = TileHelper().getTileById(entry.key);
      if (tile.tileType == TileType.Placeholder) continue;
      final item = TileScoreEntry(tile: tile, score: entry.value);
      if (tile.isThroneRoom()) {
        throne = item;
      } else if (tile.isBonusCard()) {
        bonuses.add(item);
      } else if (tile.isRoyalAttendant()) {
        attendants.add(item);
      } else {
        rooms.add(item);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tokenCellWidth =
            (constraints.maxWidth - _gap * (_tokenColumns - 1)) /
                _tokenColumns;
        final tokenScale = (tokenCellWidth - 2 * _cardPadding) /
            TileWidget.defaultTileWidthHeight;

        final roomCellWidth =
            (constraints.maxWidth - _gap * (_roomColumns - 1)) / _roomColumns;
        final roomScale = (roomCellWidth - 2 * _cardPadding) /
            TileWidget.defaultTileWidthHeight;

        final rows = <Widget>[];

        if (throne != null) {
          final throneWidth = tokenCellWidth * 2 + _gap;
          rows.add(
            Padding(
              padding: EdgeInsets.only(
                bottom: (bonuses.isNotEmpty ||
                        attendants.isNotEmpty ||
                        rooms.isNotEmpty)
                    ? _gap
                    : 0,
              ),
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: throneWidth,
                  child: TileScoreGridItem(
                    tile: throne.tile,
                    score: throne.score,
                    // Art is 2× wide; card spans two of the 3-across cells.
                    scale: tokenScale,
                  ),
                ),
              ),
            ),
          );
        }

        if (bonuses.isNotEmpty) {
          rows.add(
            Padding(
              padding: EdgeInsets.only(
                bottom: (attendants.isNotEmpty || rooms.isNotEmpty) ? _gap : 0,
              ),
              child: _centeredChunkRow(
                entries: bonuses,
                columns: _tokenColumns,
                cellWidth: tokenCellWidth,
                scale: tokenScale,
                maxWidth: constraints.maxWidth,
              ),
            ),
          );
        }

        if (attendants.isNotEmpty) {
          rows.add(
            Padding(
              padding: EdgeInsets.only(bottom: rooms.isNotEmpty ? _gap : 0),
              child: _centeredChunkRow(
                entries: attendants,
                columns: _tokenColumns,
                cellWidth: tokenCellWidth,
                scale: tokenScale,
                maxWidth: constraints.maxWidth,
              ),
            ),
          );
        }

        for (var i = 0; i < rooms.length; i += _roomColumns) {
          final slice = rooms.sublist(
            i,
            i + _roomColumns > rooms.length ? rooms.length : i + _roomColumns,
          );
          rows.add(
            Padding(
              padding: EdgeInsets.only(
                bottom: i + _roomColumns < rooms.length ? _gap : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < _roomColumns; c++) ...[
                    if (c > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: c < slice.length
                          ? TileScoreGridItem(
                              tile: slice[c].tile,
                              score: slice[c].score,
                              scale: roomScale,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(children: rows);
      },
    );
  }

  /// Centers a short final row so 1–2 bonus/attendant cards don't stretch.
  Widget _centeredChunkRow({
    required List<TileScoreEntry> entries,
    required int columns,
    required double cellWidth,
    required double scale,
    required double maxWidth,
  }) {
    final children = <Widget>[];
    for (var i = 0; i < entries.length; i += columns) {
      final slice = entries.sublist(
        i,
        i + columns > entries.length ? entries.length : i + columns,
      );
      if (i > 0) {
        children.add(const SizedBox(height: _gap));
      }
      if (slice.length >= columns) {
        children.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: _gap),
                Expanded(
                  child: TileScoreGridItem(
                    tile: slice[c].tile,
                    score: slice[c].score,
                    scale: scale,
                  ),
                ),
              ],
            ],
          ),
        );
      } else {
        final rowWidth =
            slice.length * cellWidth + (slice.length - 1) * _gap;
        children.add(
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: rowWidth.clamp(0, maxWidth),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < slice.length; c++) ...[
                    if (c > 0) const SizedBox(width: _gap),
                    SizedBox(
                      width: cellWidth,
                      child: TileScoreGridItem(
                        tile: slice[c].tile,
                        score: slice[c].score,
                        scale: scale,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }
    }
    return Column(children: children);
  }
}

class TileScoreEntry {
  final Tile tile;
  final int score;

  const TileScoreEntry({required this.tile, required this.score});
}
