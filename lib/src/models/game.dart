
import 'dart:collection';
import 'dart:math';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/player_helper.dart';
import 'package:btcc/src/utils/string_helper.dart';

class Game {

  UnmodifiableListView<Castle> get castles {
    return UnmodifiableListView((hiveGame.castles ?? []).map((e) => Castle.fromHiveCastle(e)).toList());
  }

  String get title {
    final t = hiveGame.title;
    if (t != null && t.trim().isNotEmpty) return t.trim();
    if (hiveGame.created != null) {
      return StringHelper.getMonthDayYear(hiveGame.created!);
    }
    return 'Game';
  }

  UnmodifiableListView<String> get playerNames {
    return UnmodifiableListView(List<String>.from(hiveGame.playerNames ?? const []));
  }

  UnmodifiableListView<String> get slottedPlayers {
    final n = castles.length;
    final all = playerNames;
    if (n == 0) return UnmodifiableListView(const []);
    return UnmodifiableListView(all.take(n).toList());
  }

  UnmodifiableListView<String> get benchPlayers {
    final n = castles.length;
    final all = playerNames;
    if (all.length <= n) return UnmodifiableListView(const []);
    return UnmodifiableListView(all.skip(n).toList());
  }

  late HiveGame hiveGame;

  Game.fromHiveGame(HiveGame hiveGame) {
    this.hiveGame = hiveGame;
    recalculateScores();
  }

  /// Index of the left castle in the winning adjacent pair, or null.
  int? getWinningPairLeftIndex() {
    if (castles.length < 3) {
      return null;
    }

    int bestScore = -1;
    int? bestLeft;
    MapEntry<Castle, Castle>? best;

    for (int i = 0; i < castles.length; i++) {
      Castle left = castles[i];
      Castle right = castles[(i + 1) % castles.length];
      var entry = MapEntry<Castle, Castle>(left, right);
      int score = getLowerScoreFromPair(entry);

      if (best == null || score > bestScore) {
        bestScore = score;
        best = entry;
        bestLeft = i;
      } else if (score == bestScore) {
        var tieBreak = breakTie(best, entry);
        best = tieBreak;
        bestScore = getLowerScoreFromPair(tieBreak);
        if (_samePair(tieBreak, entry)) {
          bestLeft = i;
        }
      }
    }

    return bestLeft;
  }

  bool _samePair(MapEntry<Castle, Castle> a, MapEntry<Castle, Castle> b) {
    final aKey = a.key.hiveCastle?.key;
    final aVal = a.value.hiveCastle?.key;
    final bKey = b.key.hiveCastle?.key;
    final bVal = b.value.hiveCastle?.key;
    return aKey != null && aVal != null && aKey == bKey && aVal == bVal;
  }

  int? getWinningPlayerIndex() {
    return PlayerHelper.winningPlayerIndexForPair(
      getWinningPairLeftIndex(),
      castles.length,
    );
  }

  MapEntry<Castle, Castle>? getWinningCastle() {
    final leftIndex = getWinningPairLeftIndex();
    if (leftIndex == null) return null;
    return MapEntry(
      castles[leftIndex],
      castles[(leftIndex + 1) % castles.length],
    );
  }

  int? getPlayerScore(int playerIndex) {
    if (playerIndex < 0 || playerIndex >= castles.length || castles.length < 3) {
      return null;
    }
    final left = castles[playerIndex];
    final right = castles[(playerIndex + 1) % castles.length];
    return getLowerScoreFromPair(MapEntry(left, right));
  }

  /// Which adjacent castle sets this player's score (the lower one).
  /// `-1` = castle above (left of pair), `1` = castle below (right of pair),
  /// `0` = tie. Null when the player has no scored pair.
  int? getPlayerPrimaryCastleDirection(int playerIndex) {
    if (playerIndex < 0 || playerIndex >= castles.length || castles.length < 3) {
      return null;
    }
    final above = castles[playerIndex].getScore();
    final below = castles[(playerIndex + 1) % castles.length].getScore();
    if (above < below) return -1;
    if (below < above) return 1;
    return 0;
  }

  MapEntry<Castle, Castle> breakTie(MapEntry<Castle, Castle> a,
    MapEntry<Castle, Castle> b) {
    
    int aHigh = getHigherScoreFromPair(a);
    int bHigh = getHigherScoreFromPair(b);
    if (aHigh > bHigh) {
      return a;
    }
    else if (aHigh < bHigh) {
      return b;
    }
    else {
      int aSpecial = getNumberOfSpecialRooms(a);
      int bSpecial = getNumberOfSpecialRooms(b);
      if (aSpecial > bSpecial) {
        return a;
      }
      else if (aSpecial < bSpecial) {
        return b;
      }
      else {
        return a;
      }
    }
  }

  int getLowerScoreFromPair(MapEntry<Castle, Castle> entry) {
    return min(entry.key.getScore(), entry.value.getScore());
  }

  int getHigherScoreFromPair(MapEntry<Castle, Castle> entry) {
    return max(entry.key.getScore(), entry.value.getScore());
  }

  int getNumberOfSpecialRooms(MapEntry<Castle, Castle> entry) {
    return entry.key.totalSpecial + entry.value.totalSpecial;
  }

  void recalculateScores() {
    if (castles.length < 3) {
      return;
    }

    for (int i = 0; i < castles.length; i++) {
      int indexLeft = (i+castles.length-1)%castles.length;
      int indexRight = (i+1)%castles.length;
      Castle castle = castles[i];
      castle.scoreCastle([castles[indexLeft], castles[indexRight]]);
    }
  }

}
