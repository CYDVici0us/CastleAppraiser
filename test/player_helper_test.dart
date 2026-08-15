import 'package:btcc/src/utils/player_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayerHelper.nextCastleTitle', () {
    test('starts at Castle 1', () {
      expect(PlayerHelper.nextCastleTitle([]), 'Castle 1');
    });

    test('increments from max existing number', () {
      expect(
        PlayerHelper.nextCastleTitle(['Castle 1', 'Castle 3', 'My Castle']),
        'Castle 4',
      );
    });
  });

  group('PlayerHelper.nextPlayerName', () {
    test('starts at Player 1', () {
      expect(PlayerHelper.nextPlayerName([]), 'Player 1');
    });

    test('increments from max', () {
      expect(PlayerHelper.nextPlayerName(['Player 1', 'Alice', 'Player 2']), 'Player 3');
    });
  });

  group('PlayerHelper.ensureSlotPlayers', () {
    test('appends players to match slot count', () {
      final result = PlayerHelper.ensureSlotPlayers(['Player 1'], 3);
      expect(result.length, 3);
      expect(result[0], 'Player 1');
      expect(result[1], 'Player 2');
      expect(result[2], 'Player 3');
    });

    test('does not remove extras when shrinking', () {
      final result = PlayerHelper.ensureSlotPlayers(
        ['Player 1', 'Player 2', 'Player 3', 'Extra'],
        2,
      );
      expect(result, ['Player 1', 'Player 2', 'Player 3', 'Extra']);
    });
  });

  group('PlayerHelper.cascadeMove', () {
    test('moves later player into earlier slot and cascades', () {
      // Reorderable semantics: move index 3 to index 1
      final result = PlayerHelper.cascadeMove(
        ['P1', 'P2', 'P3', 'P4'],
        3,
        1,
      );
      expect(result, ['P1', 'P4', 'P2', 'P3']);
    });

    test('moves earlier player downward', () {
      final result = PlayerHelper.cascadeMove(
        ['P1', 'P2', 'P3', 'P4'],
        0,
        3,
      );
      expect(result, ['P2', 'P3', 'P1', 'P4']);
    });
  });

  group('PlayerHelper.winningPlayerIndexForPair', () {
    test('returns left castle index when valid', () {
      expect(PlayerHelper.winningPlayerIndexForPair(1, 3), 1);
    });

    test('returns null when fewer than 3 castles', () {
      expect(PlayerHelper.winningPlayerIndexForPair(0, 2), isNull);
    });
  });
}
