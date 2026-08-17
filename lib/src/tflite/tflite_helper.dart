
import 'dart:collection';

import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/statistics_helper.dart';
import 'package:btcc/src/utils/tile_helper.dart';

class TfliteHelper {

  /// Non-max suppression that keeps neighboring *different* tiles.
  /// Same label: suppress when IoU > [sameClassIou].
  /// Different label: only suppress near-duplicate boxes (IoU > [crossClassIou]).
  /// Throne rooms are never removed by cross-class overlap (attendants/bonus
  /// cards sit on them and would otherwise wipe the TR* box).
  static List<TfliteProcessedGuess> classAwareNms(
    List<TfliteProcessedGuess> guesses, {
    double sameClassIou = 0.45,
    double crossClassIou = 0.7,
  }) {
    final copy = List<TfliteProcessedGuess>.from(guesses)
      ..sort((a, b) => b.score.compareTo(a.score));
    final best = <TfliteProcessedGuess>[];
    while (copy.isNotEmpty) {
      final top = copy.removeAt(0);
      best.add(top);
      copy.removeWhere((g) {
        final iou = top.calculateOverlap(g);
        if (g.label == top.label) return iou > sameClassIou;
        if (isThroneRoom(g)) return false;
        if (isThroneRoom(top) && isNonTile(g)) return false;
        final gArea = (g.xMax - g.xMin) * (g.yMax - g.yMin);
        final topArea = (top.xMax - top.xMin) * (top.yMax - top.yMin);
        if (gArea > topArea * 1.8) {
          final inter = _intersectionArea(top, g);
          if (topArea > 0 && inter / topArea > 0.7) return false;
        }
        return iou > crossClassIou;
      });
    }
    return best;
  }

  static double _intersectionArea(
    TfliteProcessedGuess a,
    TfliteProcessedGuess b,
  ) {
    final xMinInter = a.xMin > b.xMin ? a.xMin : b.xMin;
    final xMaxInter = a.xMax < b.xMax ? a.xMax : b.xMax;
    final yMinInter = a.yMin > b.yMin ? a.yMin : b.yMin;
    final yMaxInter = a.yMax < b.yMax ? a.yMax : b.yMax;
    final w = xMaxInter - xMinInter;
    final h = yMaxInter - yMinInter;
    if (w <= 0 || h <= 0) return 0;
    return w * h;
  }

  static GridList<TileId> convertCastleToStoredCastle(Castle castle) {
    return convertToStoredCastle(castle.castleTiles);
  }

  static GridList<TileId> convertToStoredCastle(GridList<Tile> tiles) {
    return new GridList<TileId>(
      tiles.width,
      tiles.items.map((e) => e.id).toList()
    );
  }

  static GridList<Tile> convertGuessesToCastle(List<TfliteProcessedGuess> pGuesses){
    if (pGuesses.isEmpty) {
      log('No guesses');
      return GridList<Tile>(3, createEmptyTileList(3, 3));
    }

    // Highest score first so first-to-empty placement keeps the best detection.
    final guesses = List<TfliteProcessedGuess>.from(pGuesses)
      ..sort((a, b) => b.score.compareTo(a.score));

    // Attendants sit on the throne; if the model never emitted a TR* class
    // (or NMS wiped it), synthesize a throne under the attendants so Confirm
    // can still open.
    if (!guesses.any(isThroneRoom)) {
      final inferred = inferThroneFromAttendants(guesses);
      if (inferred != null) {
        log('inferred throne from attendants at '
            '(${inferred.xMin.toStringAsFixed(0)},${inferred.yMin.toStringAsFixed(0)})-'
            '(${inferred.xMax.toStringAsFixed(0)},${inferred.yMax.toStringAsFixed(0)})');
        guesses.add(inferred);
        guesses.sort((a, b) => b.score.compareTo(a.score));
      }
    }

    log('Best Guesses:');
    log(guesses);
    final stats = GuessStats.getGuessStats(guesses);
    stats.printStats();

    var castleHeight =
        ((stats.maxY - stats.minY) / stats.averageY).round() + 2;
    var castleWidth =
        ((stats.maxX - stats.minX) / stats.averageX).round() + 2;
    // Token row needs slots (0..3, 0); keep at least 4 columns.
    if (castleWidth < 4) castleWidth = 4;
    if (castleHeight < 2) castleHeight = 2;
    if (!castleWidth.isFinite || castleWidth < 1) castleWidth = 4;
    if (!castleHeight.isFinite || castleHeight < 1) castleHeight = 3;

    var castleTiles = GridList<Tile>(
      castleWidth,
      createEmptyTileList(castleWidth, castleHeight),
    );

    TfliteProcessedGuess? throneRoomGuess;
    int? throneRoomBestX;
    int? throneRoomBestY;
    final bonusCards = <({Tile tile, double score})>[];
    final royalAttendants = <({Tile tile, double score})>[];

    for (final guess in guesses) {
      if (isNonTile(guess)) {
        final already = <Tile>[
          ...bonusCards.map((e) => e.tile),
          ...royalAttendants.map((e) => e.tile),
        ];
        final tile = getCorrectTile(guess, already);
        switch (tile.tileType) {
          case TileType.RoyalAttendant:
            royalAttendants.add((tile: tile, score: guess.score));
            break;
          case TileType.BonusCard:
            bonusCards.add((tile: tile, score: guess.score));
            break;
          default:
            break;
        }
        continue;
      }

      final bestx = getBestX(stats, guess) + 1;
      final besty = getBestY(stats, guess) + 1;
      if (isThroneRoom(guess)) {
        // Keep the highest-scoring throne (list is score-sorted).
        if (throneRoomGuess == null) {
          throneRoomGuess = guess;
          throneRoomBestX = bestx - 1;
          throneRoomBestY = besty;
        }
      } else {
        _placeIfEmptyOrBetter(
          castleTiles,
          bestx,
          besty,
          getCorrectTile(guess, castleTiles.items),
        );
      }
    }

    if (throneRoomBestX == null ||
        throneRoomBestY == null ||
        throneRoomGuess == null) {
      log('No throneroom found');
    } else {
      castleTiles = _placeThroneRoom(
        castleTiles,
        throneRoomGuess,
        throneRoomBestX,
        throneRoomBestY,
      );
    }

    final topBonus = bonusCards.take(2).toList();
    final topAttendants = royalAttendants.take(2).toList();
    if (topBonus.isNotEmpty) {
      _placeIfEmptyOrBetter(castleTiles, 0, 0, topBonus[0].tile);
    }
    if (topBonus.length > 1) {
      _placeIfEmptyOrBetter(castleTiles, 1, 0, topBonus[1].tile);
    }
    if (topAttendants.isNotEmpty) {
      _placeIfEmptyOrBetter(castleTiles, 2, 0, topAttendants[0].tile);
    }
    if (topAttendants.length > 1) {
      _placeIfEmptyOrBetter(castleTiles, 3, 0, topAttendants[1].tile);
    }

    log('Resulting castle tiles:');
    log(castleTiles);
    return castleTiles;
  }

  /// Expands the grid if needed and places the 2-wide throne + placeholder.
  static GridList<Tile> _placeThroneRoom(
    GridList<Tile> castleTiles,
    TfliteProcessedGuess throneRoomGuess,
    int throneRoomBestX,
    int throneRoomBestY,
  ) {
    var grid = castleTiles;
    var x = throneRoomBestX;
    var y = throneRoomBestY;

    if (y < 0) y = 0;
    if (y >= grid.height) {
      // Grow downward.
      final extra = y - grid.height + 1;
      final grown = List<Tile>.from(grid.items);
      for (var i = 0; i < extra * grid.width; i++) {
        grown.add(Empty());
      }
      grid = GridList<Tile>(grid.width, grown);
    }

    // Prefer the requested pair; if occupied, shift one cell right.
    var placeX = x;
    if (placeX < 0) placeX = 0;
    final needsShift = !_cellEmpty(grid, placeX, y) ||
        !_cellEmpty(grid, placeX + 1, y);
    if (needsShift) placeX += 1;
    if (placeX < 0) placeX = 0;

    // Ensure width fits throne + placeholder (+ optional shift).
    final needWidth = placeX + 2;
    if (needWidth > grid.width) {
      grid = _expandWidth(grid, needWidth);
    }

    final throne = getCorrectTile(throneRoomGuess, grid.items);
    final idx = getTileIndexInList(grid, placeX, y);
    grid.items[idx] = throne;
    grid.items[idx + 1] = Placeholder();
    return grid;
  }

  static GridList<Tile> _expandWidth(GridList<Tile> grid, int newWidth) {
    if (newWidth <= grid.width) return grid;
    final grown = <Tile>[];
    for (var row = 0; row < grid.height; row++) {
      for (var col = 0; col < newWidth; col++) {
        if (col < grid.width) {
          grown.add(grid.items[row * grid.width + col]);
        } else {
          grown.add(Empty());
        }
      }
    }
    return GridList<Tile>(newWidth, grown);
  }

  static bool _cellEmpty(GridList<Tile> grid, int x, int y) {
    if (x < 0 || y < 0 || x >= grid.width || y >= grid.height) {
      return true;
    }
    return grid.items[getTileIndexInList(grid, x, y)].isEmpty();
  }

  /// Places [tile] when the cell is empty. Because callers sort by score
  /// descending, the first write wins and lower-score collisions are ignored.
  static void _placeIfEmptyOrBetter(
    GridList<Tile> grid,
    int x,
    int y,
    Tile tile,
  ) {
    if (x < 0 || y < 0 || x >= grid.width || y >= grid.height) {
      log('Skipping out-of-bounds placement at ($x,$y) for ${tile.id}');
      return;
    }
    final idx = getTileIndexInList(grid, x, y);
    if (grid.items[idx].isEmpty()) {
      grid.items[idx] = tile;
    }
  }

  static GridList<Tile> removeUnconnectedTiles(GridList<Tile> castleTiles){
    var retVal = new GridList<Tile>(castleTiles.width,createEmptyTileList(castleTiles.width,castleTiles.height));

    for(int i = 0;i<castleTiles.items.length;i++){
      if(isConnectedToThroneRoom(castleTiles,castleTiles.items[i])){
        retVal.items[i] = castleTiles.items[i];
      }
    }

    return retVal;
  }

  static bool isConnectedToThroneRoom(GridList<Tile> castleTiles, Tile t){
    Queue queue = new Queue();
    queue.add(t);
    Tile currentTile;
    while(queue.isNotEmpty){
      currentTile = queue.removeFirst();
      if(currentTile.tileType == TileType.ThroneRoom || currentTile.tileType == TileType.Placeholder)return true;
      if(!tileUp(currentTile,castleTiles).isEmpty())queue.add(tileUp(currentTile,castleTiles));
      if(!tileDown(currentTile,castleTiles).isEmpty())queue.add(tileDown(currentTile,castleTiles));
      if(!tileLeft(currentTile,castleTiles).isEmpty())queue.add(tileLeft(currentTile,castleTiles));
      if(!tileRight(currentTile,castleTiles).isEmpty())queue.add(tileRight(currentTile,castleTiles));
    }
    return false;
  }

  static int getIndexOfTile(GridList<Tile> castleTiles, Tile t){
    for(int i = 0;i<castleTiles.items.length;i++){
      if(t.id == castleTiles.items[i].id)return i;
    }
    return -1;
  }
  static Tile tileUp(Tile t, GridList<Tile> castleTiles){
    int x = getIndexOfTile(castleTiles,t);
    if(x < 0) return Empty();
    if(x-castleTiles.width<0)return Empty();
    return castleTiles.items[x-castleTiles.width];
  }
  static Tile tileDown(Tile t, GridList<Tile> castleTiles){
    int x = getIndexOfTile(castleTiles,t);
    if(x < 0) return Empty();
    if(x+castleTiles.width>castleTiles.items.length-1)return Empty();
    return castleTiles.items[x+castleTiles.width];
  }
  static Tile tileLeft(Tile t, GridList<Tile> castleTiles){
    int x = getIndexOfTile(castleTiles,t);
    if(x < 0) return Empty();
    if(x%castleTiles.width==0)return Empty();
    return castleTiles.items[x-1];

  }
  static Tile tileRight(Tile t,GridList<Tile> castleTiles){
    int x = getIndexOfTile(castleTiles,t);
    if(x < 0) return Empty();
    if(x%castleTiles.width==castleTiles.width-1)return Empty();
    return castleTiles.items[x+1];
  }

  static Tile getCorrectTile(TfliteProcessedGuess guess, List<Tile> currentTiles){
    switch (guess.label){
      case TileLabels.FOUNTAIN:
        if(!isTileInList(currentTiles,TileId.Fountain)) return TileHelper().getTileById(TileId.Fountain);
        if(!isTileInList(currentTiles,TileId.Fountain2)) return TileHelper().getTileById(TileId.Fountain2);
        if(!isTileInList(currentTiles,TileId.Fountain3)) return TileHelper().getTileById(TileId.Fountain3);
        if(!isTileInList(currentTiles,TileId.Fountain4)) return TileHelper().getTileById(TileId.Fountain4);
        if(!isTileInList(currentTiles,TileId.Fountain5)) return TileHelper().getTileById(TileId.Fountain5);
        break;
      case TileLabels.GRAND_FOYER:
        if(!isTileInList(currentTiles,TileId.GrandFoyer)) return TileHelper().getTileById(TileId.GrandFoyer);
        if(!isTileInList(currentTiles,TileId.GrandFoyer2)) return TileHelper().getTileById(TileId.GrandFoyer2);
        if(!isTileInList(currentTiles,TileId.GrandFoyer3)) return TileHelper().getTileById(TileId.GrandFoyer3);
        if(!isTileInList(currentTiles,TileId.GrandFoyer4)) return TileHelper().getTileById(TileId.GrandFoyer4);
        if(!isTileInList(currentTiles,TileId.GrandFoyer5)) return TileHelper().getTileById(TileId.GrandFoyer5);
        break;
      case TileLabels.TOWER:
        if(!isTileInList(currentTiles,TileId.Tower)) return TileHelper().getTileById(TileId.Tower);
        if(!isTileInList(currentTiles,TileId.Tower2)) return TileHelper().getTileById(TileId.Tower2);
        if(!isTileInList(currentTiles,TileId.Tower3)) return TileHelper().getTileById(TileId.Tower3);
        if(!isTileInList(currentTiles,TileId.Tower4)) return TileHelper().getTileById(TileId.Tower4);
        if(!isTileInList(currentTiles,TileId.Tower5)) return TileHelper().getTileById(TileId.Tower5);
        break;

      case TileLabels.RAM:
        if(!isTileInList(currentTiles,TileId.RoyalAttendantTaylor)) return TileHelper().getTileById(TileId.RoyalAttendantTaylor);
        if(!isTileInList(currentTiles,TileId.RoyalAttendantTaylor2)) return TileHelper().getTileById(TileId.RoyalAttendantTaylor2);
        return TileHelper().getTileById(TileId.RoyalAttendantTaylor);
      case TileLabels.RAS:
        if(!isTileInList(currentTiles,TileId.RoyalAttendantKnight)) return TileHelper().getTileById(TileId.RoyalAttendantKnight);
        if(!isTileInList(currentTiles,TileId.RoyalAttendantKnight2)) return TileHelper().getTileById(TileId.RoyalAttendantKnight2);
        return TileHelper().getTileById(TileId.RoyalAttendantKnight);
      case TileLabels.RAP:
        if(!isTileInList(currentTiles,TileId.RoyalAttendantPainter)) return TileHelper().getTileById(TileId.RoyalAttendantPainter);
        if(!isTileInList(currentTiles,TileId.RoyalAttendantPainter2)) return TileHelper().getTileById(TileId.RoyalAttendantPainter2);
        return TileHelper().getTileById(TileId.RoyalAttendantPainter);
      case TileLabels.RAT:
        if(!isTileInList(currentTiles,TileId.RoyalAttendantJester)) return TileHelper().getTileById(TileId.RoyalAttendantJester);
        if(!isTileInList(currentTiles,TileId.RoyalAttendantJester2)) return TileHelper().getTileById(TileId.RoyalAttendantJester2);
        return TileHelper().getTileById(TileId.RoyalAttendantJester);

      case TileLabels.BRA:
        if(!isTileInList(currentTiles,TileId.BallRoomPerActivity)) return TileHelper().getTileById(TileId.BallRoomPerActivity);
        if(!isTileInList(currentTiles,TileId.BallRoomPerActivity2)) return TileHelper().getTileById(TileId.BallRoomPerActivity2);
        break;
      case TileLabels.BRC:
        if(!isTileInList(currentTiles,TileId.BallRoomPerCorridor)) return TileHelper().getTileById(TileId.BallRoomPerCorridor);
        if(!isTileInList(currentTiles,TileId.BallRoomPerCorridor2)) return TileHelper().getTileById(TileId.BallRoomPerCorridor2);
        break;
      case TileLabels.BRD:
        if(!isTileInList(currentTiles,TileId.BallRoomPerDownstairs)) return TileHelper().getTileById(TileId.BallRoomPerDownstairs);
        if(!isTileInList(currentTiles,TileId.BallRoomPerDownstairs2)) return TileHelper().getTileById(TileId.BallRoomPerDownstairs2);
        break;
      case TileLabels.BRF:
        if(!isTileInList(currentTiles,TileId.BallRoomPerFood)) return TileHelper().getTileById(TileId.BallRoomPerFood);
        if(!isTileInList(currentTiles,TileId.BallRoomPerFood2)) return TileHelper().getTileById(TileId.BallRoomPerFood2);
        break;
      case TileLabels.BRL:
        if(!isTileInList(currentTiles,TileId.BallRoomPerLiving)) return TileHelper().getTileById(TileId.BallRoomPerLiving);
        if(!isTileInList(currentTiles,TileId.BallRoomPerLiving2)) return TileHelper().getTileById(TileId.BallRoomPerLiving2);
        break;
      case TileLabels.BRO:
        if(!isTileInList(currentTiles,TileId.BallRoomPerOutdoor)) return TileHelper().getTileById(TileId.BallRoomPerOutdoor);
        if(!isTileInList(currentTiles,TileId.BallRoomPerOutdoor2)) return TileHelper().getTileById(TileId.BallRoomPerOutdoor2);
        break;
      case TileLabels.BRS:
        if(!isTileInList(currentTiles,TileId.BallRoomPerSleeping)) return TileHelper().getTileById(TileId.BallRoomPerSleeping);
        if(!isTileInList(currentTiles,TileId.BallRoomPerSleeping2)) return TileHelper().getTileById(TileId.BallRoomPerSleeping2);
        break;
      case TileLabels.BRU:
        if(!isTileInList(currentTiles,TileId.BallRoomPerUtility)) return TileHelper().getTileById(TileId.BallRoomPerUtility);
        if(!isTileInList(currentTiles,TileId.BallRoomPerUtility2)) return TileHelper().getTileById(TileId.BallRoomPerUtility2);
        break;
      default:
        return TileHelper().getTileByLabel(guess.label);
    }
    
    throw new Exception("Could not find tile from guess label");
  }

  static bool isTileInList(List<Tile> currentTiles, TileId tId){
    bool retVal = false;
    for (int i = 0; i<currentTiles.length;i++){
      if(currentTiles[i].id == tId) return true;
    }
    return retVal;
  }

  static bool isNonTile(TfliteProcessedGuess guess){
    bool retVal = false;
    var tile = getCorrectTile(guess, <Tile>[]);
    switch(tile.tileType){
      case TileType.RoyalAttendant: retVal = true; break;
      case TileType.BonusCard: retVal = true; break;
      default: retVal = false; break;
    }
    return retVal;
  }

  static bool isThroneRoom(TfliteProcessedGuess guess){
    return guess.label == TileLabels.TRLS ||
        guess.label == TileLabels.TRLC ||
        guess.label == TileLabels.TRUS ||
        guess.label == TileLabels.TRCD ||
        guess.label == TileLabels.TRFS ||
        guess.label == TileLabels.TRUF ||
        guess.label == TileLabels.TRCF ||
        guess.label == TileLabels.TRAO;
  }

  /// Room-tile detections only (excludes throne, bonus cards, attendants).
  static int countRoomDetections(List<TfliteProcessedGuess> guesses) {
    return guesses
        .where((g) => !isNonTile(g) && !isThroneRoom(g))
        .length;
  }

  /// Non-empty room tiles on a built grid (excludes throne, placeholder, tokens).
  static int countPlacedRoomTiles(GridList<Tile> grid) {
    var count = 0;
    for (final t in grid.items) {
      if (t.isEmpty()) continue;
      switch (t.tileType) {
        case TileType.ThroneRoom:
        case TileType.Placeholder:
        case TileType.BonusCard:
        case TileType.RoyalAttendant:
          continue;
        default:
          count++;
      }
    }
    return count;
  }

  /// When [expected] is set, true if fewer room tiles were found/placed.
  static bool isUnderExpectedRoomCount(int found, int? expected) {
    return expected != null && expected > 0 && found < expected;
  }

  /// When royal attendants are detected but no throne class survived, place a
  /// ~2×1 throne under the attendants (they sit on the throne room tile).
  static TfliteProcessedGuess? inferThroneFromAttendants(
    List<TfliteProcessedGuess> guesses,
  ) {
    final attendants = <TfliteProcessedGuess>[];
    final rooms = <TfliteProcessedGuess>[];
    for (final g in guesses) {
      if (isThroneRoom(g)) return null;
      if (isNonTile(g)) {
        final tile = getCorrectTile(g, const <Tile>[]);
        if (tile.tileType == TileType.RoyalAttendant) {
          attendants.add(g);
        }
        continue;
      }
      rooms.add(g);
    }
    if (attendants.isEmpty) return null;

    var sumCx = 0.0;
    var sumCy = 0.0;
    for (final a in attendants) {
      sumCx += (a.xMin + a.xMax) / 2;
      sumCy += (a.yMin + a.yMax) / 2;
    }
    final cx = sumCx / attendants.length;
    final cy = sumCy / attendants.length;

    // Tile pitch from room boxes when available; else from attendants.
    final pitchSrc = rooms.isNotEmpty ? rooms : attendants;
    var sumW = 0.0;
    var sumH = 0.0;
    for (final g in pitchSrc) {
      sumW += g.xMax - g.xMin;
      sumH += g.yMax - g.yMin;
    }
    final tileW = sumW / pitchSrc.length;
    final tileH = sumH / pitchSrc.length;
    // Throne is 2 tiles wide; keep attendants near the top of the box.
    final width = tileW * 2.0;
    final height = tileH * 1.05;
    final xMin = cx - width / 2;
    final xMax = cx + width / 2;
    final yMin = cy - height * 0.25;
    final yMax = yMin + height;

    return TfliteProcessedGuess(
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
      label: TileLabels.TRCD,
      probability: 0.55,
      confidence: 0.55,
      score: 0.3,
    );
  }

  static int getBestX(GuessStats stats, TfliteProcessedGuess guess){
    int retVal = 0;
    retVal = ((((guess.xMax+guess.xMin)/2)-stats.minX)~/stats.averageX);
    return retVal;
  }

  static int getBestY(GuessStats stats, TfliteProcessedGuess guess){
    int retVal = 0;
    retVal = ((((guess.yMax+guess.yMin)/2)-stats.minY)~/stats.averageY);
    return retVal;
  }

  static int getTileIndexInList(GridList<Tile> list,int x, int y){
    return (list.width * y) + x;
  }

  static List<Tile> createEmptyTileList(int x,int y){
    List<Tile> retVal = <Tile>[];
    for(int i =0;i<x;i++){
      for(int j = 0;j<y;j++){
        retVal.add(Empty());
      }
    }
    return retVal;
  }
}

class GuessStats{

  double minX;
  double maxX;
  double minY;
  double maxY;
  double averageX;
  double averageY;
  double stdX;
  double stdY;

  GuessStats({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.averageX,
    required this.averageY,
    required this.stdX,
    required this.stdY,
  });

  static GuessStats getGuessStats(List<TfliteProcessedGuess> pg){
    final xposVals = <double>[];
    final yposVals = <double>[];
    final xVals = <double>[];
    final yVals = <double>[];
    final throneSizeX = <double>[];
    final throneSizeY = <double>[];

    for (final tempGuess in pg) {
      // Bonus cards / attendants sit outside the castle and must not skew
      // extents or average tile pitch used for grid binning.
      if (TfliteHelper.isNonTile(tempGuess)) {
        continue;
      }

      xposVals.add(tempGuess.xMax);
      xposVals.add(tempGuess.xMin);
      yposVals.add(tempGuess.yMax);
      yposVals.add(tempGuess.yMin);

      final w = tempGuess.xMax - tempGuess.xMin;
      final h = tempGuess.yMax - tempGuess.yMin;
      if (TfliteHelper.isThroneRoom(tempGuess)) {
        // Throne is ~2 tiles wide; keep for fallback pitch only.
        throneSizeX.add(w / 2.0);
        throneSizeY.add(h);
      } else {
        xVals.add(w);
        yVals.add(h);
      }
    }

    // Throne-only photo: derive cell size from the throne box.
    if (xVals.isEmpty && throneSizeX.isNotEmpty) {
      xVals.addAll(throneSizeX);
    }
    if (yVals.isEmpty && throneSizeY.isNotEmpty) {
      yVals.addAll(throneSizeY);
    }

    // Last resort so we never divide by zero / NaN.
    if (xVals.isEmpty) xVals.add(1);
    if (yVals.isEmpty) yVals.add(1);
    if (xposVals.isEmpty) {
      xposVals.addAll([0, 1]);
      yposVals.addAll([0, 1]);
    }

    final tempMiX = StatHelper.getMin(xposVals);
    final tempMaX = StatHelper.getMax(xposVals);
    final tempMiY = StatHelper.getMin(yposVals);
    final tempMaY = StatHelper.getMax(yposVals);

    final tempSX = StatHelper.getSTD(xVals);
    final tempSY = StatHelper.getSTD(yVals);

    final tempAX = StatHelper.getMedian(xVals);
    final tempAY = StatHelper.getMedian(yVals);

    log('The Median X (tile pitch): $tempAX');
    log('The Median Y (tile pitch): $tempAY');

    return GuessStats(
      minX: tempMiX,
      maxX: tempMaX,
      minY: tempMiY,
      maxY: tempMaY,
      averageX: tempAX > 0 ? tempAX : 1,
      averageY: tempAY > 0 ? tempAY : 1,
      stdX: tempSX,
      stdY: tempSY,
    );
  }

  void printStats(){
    log('The minimum X pos: ${this.minX}');
    log('The max X pos: ${this.maxX}');
    log('The minimum Y pos: ${this.minY}');
    log('The max Y pos: ${this.maxY}');
    log('Average X Length: ${this.averageX}');
    log('X Std: ${this.stdX}');
    log('Average Y Length: ${this.averageY}');
    log('Y Std: ${this.stdY}');
  }

}