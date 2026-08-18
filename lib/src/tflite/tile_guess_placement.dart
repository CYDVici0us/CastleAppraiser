import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/cell_guess_info.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:btcc/src/utils/log.dart';

/// Safe tile assignment from a detection guess.
class TileGuessPlacement {
  TileGuessPlacement._();

  static Tile? tryGetTile(
    TfliteProcessedGuess guess,
    List<Tile> currentTiles,
  ) {
    try {
      return TfliteHelper.getCorrectTile(guess, currentTiles);
    } catch (ex) {
      log('getCorrectTile failed for ${guess.label}: $ex');
      return null;
    }
  }

  static CellGuessInfo infoFromGuess({
    required TfliteProcessedGuess? guess,
    required double coverage,
    List<TileLabels> alternatives = const [],
    bool forceUnidentified = false,
  }) {
    if (forceUnidentified || guess == null) {
      return CellGuessInfo.unidentifiedCell(alternatives: alternatives);
    }
    return CellGuessInfo.fromGuess(
      score: guess.score,
      coverage: coverage,
      alternatives: alternatives,
    );
  }
}
