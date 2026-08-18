import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/cell_guess_info.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/utils/grid_expander.dart';

/// Grid plus session-only per-cell guess metadata from ML conversion.
class CastleBuildResult {
  final GridList<Tile> grid;
  final Map<int, CellGuessInfo> cellGuesses;

  const CastleBuildResult({
    required this.grid,
    this.cellGuesses = const {},
  });

  int get uncertainCount =>
      cellGuesses.values.where((g) => g.needsReview).length;

  int get placedRoomCount => TfliteHelper.countPlacedRoomTiles(grid);

  int get unidentifiedOccupiedCount =>
      cellGuesses.values.where((g) => g.unidentified).length;

  bool shouldOfferGridMode({required int? expectedRoomTileCount}) {
    if (expectedRoomTileCount == null || expectedRoomTileCount <= 0) {
      return false;
    }
    return placedRoomCount < (expectedRoomTileCount * 0.5).ceil();
  }
}
