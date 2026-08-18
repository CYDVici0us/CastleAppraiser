import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/castle_build_result.dart';
import 'package:btcc/src/tflite/castle_occupancy.dart';
import 'package:btcc/src/tflite/cell_guess_info.dart';
import 'package:btcc/src/tflite/throne_anchored_lattice.dart';
import 'package:btcc/src/tflite/tile_guess_placement.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/token_tile_grid.dart';

/// Throne-anchored guess → grid conversion with occupancy + guess sidecar.
class CastleConversion {
  CastleConversion._();

  static CastleBuildResult convertGuessesToCastleWithInfo(
    List<TfliteProcessedGuess> pGuesses,
  ) {
    if (pGuesses.isEmpty) {
      log('No guesses');
      return CastleBuildResult(
        grid: GridList<Tile>(3, TfliteHelper.createEmptyTileList(3, 3)),
      );
    }

    final guesses = TfliteHelper.suppressNearbySameLabel(
      List<TfliteProcessedGuess>.from(pGuesses)
        ..sort((a, b) => b.score.compareTo(a.score)),
    );

    if (!guesses.any(TfliteHelper.isThroneRoom)) {
      final inferred = TfliteHelper.inferThroneFromAttendants(guesses);
      if (inferred != null) {
        log('inferred throne from attendants');
        guesses.add(inferred);
        guesses.sort((a, b) => b.score.compareTo(a.score));
      }
    }

    TfliteProcessedGuess? throneGuess;
    for (final g in guesses) {
      if (TfliteHelper.isThroneRoom(g)) {
        throneGuess = g;
        break;
      }
    }
    if (throneGuess == null) {
      log('No throneroom found — falling back to legacy binning');
      return CastleBuildResult(
        grid: _legacyConvert(guesses),
      );
    }

    var lattice = ThroneAnchoredLattice.fromGuess(throneGuess);
    final roomGuesses = guesses
        .where((g) => !TfliteHelper.isNonTile(g) && !TfliteHelper.isThroneRoom(g))
        .toList();

    // Pitch refinement from room centers.
    if (roomGuesses.isNotEmpty) {
      final samples = roomGuesses.map((g) {
        final (gx, gy) = lattice.cellForGuess(g);
        return (
          gx,
          gy,
          (g.xMin + g.xMax) / 2,
          (g.yMin + g.yMax) / 2,
        );
      });
      lattice = lattice.refinePitch(samples: samples);
    }

    // Map rooms to relative cells; keep best unused unique label per cell.
    final cellToGuess = <(int, int), TfliteProcessedGuess>{};
    final usedCopies = <Object, int>{};
    for (final g in roomGuesses) {
      final cell = lattice.cellForGuess(g);
      if (cell == (0, 0) || cell == (1, 0)) continue;
      if (cellToGuess.containsKey(cell)) continue;
      final already = usedCopies[g.label] ?? 0;
      if (already >= TfliteHelper.maxCopiesForLabel(g.label)) continue;
      cellToGuess[cell] = g;
      usedCopies[g.label] = already + 1;
    }

    // Interior false bonus → occupied-unidentified at binned cell.
    final gapBonuses = _interiorFalseBonuses(guesses);
    for (final g in gapBonuses) {
      final cell = lattice.cellForGuess(g);
      cellToGuess.putIfAbsent(cell, () => g);
    }

    var occupied = cellToGuess.keys.toSet();
    occupied.add((0, 0));
    occupied.add((1, 0));
    occupied = CastleOccupancy.pruneDisconnected(
      cells: occupied,
      throneCell: (0, 0),
    );
    occupied = CastleOccupancy.morphologicalClosing(occupied);

    final layout = CastleOccupancy.gridLayout(occupied);
    final grid = GridList<Tile>(
      layout.width,
      TfliteHelper.createEmptyTileList(layout.width, layout.height),
    );
    final guessInfo = <int, CellGuessInfo>{};

    void placeAtRelative(int gx, int gy, Tile tile, CellGuessInfo? info) {
      final idx = layout.toIndex(gx, gy);
      if (idx < 0 || idx >= grid.items.length) return;
      grid.items[idx] = tile;
      if (info != null) guessInfo[idx] = info;
    }

    // Throne + placeholder at relative (0,0) and (1,0).
    final throneTile = TfliteHelper.getCorrectTile(throneGuess, grid.items);
    final throneIdx = layout.toIndex(0, 0);
    final phIdx = layout.toIndex(1, 0);
    if (throneIdx >= 0 && throneIdx < grid.items.length) {
      grid.items[throneIdx] = throneTile;
      guessInfo[throneIdx] = CellGuessInfo.fromGuess(
        score: throneGuess.score,
        coverage: 1.0,
      );
    }
    if (phIdx >= 0 && phIdx < grid.items.length) {
      grid.items[phIdx] = Placeholder();
    }

    for (final entry in cellToGuess.entries) {
      final (gx, gy) = entry.key;
      if (gy == 0 && (gx == 0 || gx == 1)) continue;
      if (!occupied.contains((gx, gy))) continue;

      final g = entry.value;
      final cov = CastleOccupancy.coverageOfCell(
        lattice: lattice,
        gx: gx,
        gy: gy,
        xMin: g.xMin,
        xMax: g.xMax,
        yMin: g.yMin,
        yMax: g.yMax,
      );

      final isFalseBonus =
          TfliteHelper.isNonTile(g) && gapBonuses.contains(g);
      if (isFalseBonus) {
        placeAtRelative(
          gx,
          gy,
          Empty(),
          CellGuessInfo.unidentifiedCell(),
        );
        continue;
      }

      final tile = TileGuessPlacement.tryGetTile(g, grid.items);
      if (tile != null) {
        placeAtRelative(
          gx,
          gy,
          tile,
          TileGuessPlacement.infoFromGuess(guess: g, coverage: cov),
        );
      } else {
        placeAtRelative(
          gx,
          gy,
          Empty(),
          CellGuessInfo.unidentifiedCell(),
        );
      }
    }

    // Morphological holes without a guess → unidentified occupied.
    for (final cell in occupied) {
      if (cellToGuess.containsKey(cell)) continue;
      if (cell == (0, 0) || cell == (1, 0)) continue;
      placeAtRelative(cell.$1, cell.$2, Empty(), CellGuessInfo.unidentifiedCell());
    }

    final tokens = TfliteHelper.collectTokenTiles(
      guesses.where((g) => !gapBonuses.contains(g)).toList(),
    );
    var outGrid = grid;
    var outGuesses = Map<int, CellGuessInfo>.from(guessInfo);
    if (tokens.isNotEmpty) {
      outGrid = TokenTileGrid.mergeTokenTilesIntoGrid(
        grid,
        tokens,
        getEmpty: () => Empty(),
      );
      if (outGrid.height > grid.height) {
        final remapped = <int, CellGuessInfo>{};
        for (final entry in guessInfo.entries) {
          final x = entry.key % grid.width;
          final y = entry.key ~/ grid.width;
          remapped[x + (y + 1) * outGrid.width] = entry.value;
        }
        outGuesses = remapped;
      }
    }

    log('castle conversion: ${outGrid.width}x${outGrid.height}, '
        '${outGuesses.values.where((g) => g.unidentified).length} unidentified');
    return CastleBuildResult(grid: outGrid, cellGuesses: outGuesses);
  }

  static List<TfliteProcessedGuess> _interiorFalseBonuses(
    List<TfliteProcessedGuess> guesses,
  ) {
    return guesses.where((g) {
      if (!TfliteHelper.isNonTile(g)) return false;
      final tile = TfliteHelper.getCorrectTile(g, const <Tile>[]);
      if (tile.tileType != TileType.BonusCard) return false;
      return TfliteHelper.bonusCardInsideRoomCluster(g, guesses);
    }).toList();
  }

  static GridList<Tile> _legacyConvert(List<TfliteProcessedGuess> guesses) {
    return TfliteHelper.convertGuessesToCastleLegacy(guesses);
  }
}
