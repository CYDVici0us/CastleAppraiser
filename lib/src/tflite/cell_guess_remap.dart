import 'dart:convert';

import 'package:btcc/src/models/tile.dart';
import 'package:btcc/src/tflite/cell_guess_info.dart';
import 'package:btcc/src/utils/grid_expander.dart';

/// Reindex session ML metadata after perimeter normalize / grid growth.
Map<int, CellGuessInfo> remapCellGuesses(
  Map<int, CellGuessInfo> guesses,
  GridNormalizeResult normalized,
) {
  if (guesses.isEmpty) return guesses;
  final out = <int, CellGuessInfo>{};
  for (final e in guesses.entries) {
    final mapped = normalized.mapIndex(e.key);
    if (mapped != null) out[mapped] = e.value;
  }
  return out;
}

(int, int) throneOriginOf(GridList<Tile> grid) {
  for (var i = 0; i < grid.items.length; i++) {
    if (grid.items[i].isThroneRoom()) {
      return (i % grid.width, i ~/ grid.width);
    }
  }
  return (0, 0);
}

/// Throne-relative `"gx,gy"` keys, same convention as fixture [labels].
Map<String, Map<String, Object?>> cellGuessesToThroneMap(
  GridList<Tile> grid,
  Map<int, CellGuessInfo> guesses,
) {
  if (guesses.isEmpty) return {};
  final origin = throneOriginOf(grid);
  final out = <String, Map<String, Object?>>{};
  for (final e in guesses.entries) {
    final i = e.key;
    if (i < 0 || i >= grid.items.length) continue;
    final tile = grid.items[i];
    if (tile.isBonusCard() || tile.isRoyalAttendant()) continue;
    final gx = (i % grid.width) - origin.$1;
    final gy = (i ~/ grid.width) - origin.$2;
    out['$gx,$gy'] = e.value.toJson();
  }
  return out;
}

Map<int, CellGuessInfo> cellGuessesFromThroneMap(
  GridList<Tile> grid,
  Map raw,
) {
  if (raw.isEmpty) return {};
  final origin = throneOriginOf(grid);
  final out = <int, CellGuessInfo>{};
  for (final e in raw.entries) {
    final parts = e.key.toString().split(',');
    if (parts.length != 2) continue;
    final gx = int.tryParse(parts[0].trim());
    final gy = int.tryParse(parts[1].trim());
    if (gx == null || gy == null) continue;
    final x = gx + origin.$1;
    final y = gy + origin.$2;
    if (x < 0 || y < 0 || x >= grid.width) continue;
    final i = x + y * grid.width;
    if (i < 0 || i >= grid.items.length) continue;
    final tile = grid.items[i];
    if (tile.isBonusCard() || tile.isRoyalAttendant()) continue;
    final value = e.value;
    if (value is Map) {
      out[i] = CellGuessInfo.fromJson(value);
    }
  }
  return out;
}

String? encodeCellGuessesJson(
  GridList<Tile> grid,
  Map<int, CellGuessInfo> guesses,
) {
  final map = cellGuessesToThroneMap(grid, guesses);
  if (map.isEmpty) return null;
  return jsonEncode(map);
}

Map<int, CellGuessInfo> decodeCellGuessesJson(
  GridList<Tile> grid,
  String? json,
) {
  if (json == null || json.isEmpty) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return {};
    return cellGuessesFromThroneMap(grid, decoded);
  } catch (_) {
    return {};
  }
}
