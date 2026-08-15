/// Pure helpers for player naming, castle auto-titles, and cascade reorder.
class PlayerHelper {
  static final RegExp _castleNumberPattern = RegExp(r'^Castle\s+(\d+)$', caseSensitive: false);
  static final RegExp _playerNumberPattern = RegExp(r'^Player\s+(\d+)$', caseSensitive: false);

  static String nextCastleTitle(Iterable<String?> existingTitles) {
    int maxNum = 0;
    for (final title in existingTitles) {
      if (title == null) continue;
      final match = _castleNumberPattern.firstMatch(title.trim());
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    return 'Castle ${maxNum + 1}';
  }

  static String nextPlayerName(Iterable<String> existingNames) {
    int maxNum = 0;
    for (final name in existingNames) {
      final match = _playerNumberPattern.firstMatch(name.trim());
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    return 'Player ${maxNum + 1}';
  }

  /// Ensures at least [slotCount] players exist (circular slots for N castles).
  /// Appends auto-named players; never removes names when shrinking.
  static List<String> ensureSlotPlayers(List<String> players, int slotCount) {
    final result = List<String>.from(players);
    while (result.length < slotCount) {
      result.add(nextPlayerName(result));
    }
    return result;
  }

  /// Moves the player at [fromIndex] to [toIndex], shifting others (cascade).
  /// [toIndex] uses ReorderableListView semantics (index before removal).
  static List<String> cascadeMove(List<String> players, int fromIndex, int toIndex) {
    if (players.isEmpty) return players;
    if (fromIndex < 0 || fromIndex >= players.length) return List<String>.from(players);

    var newIndex = toIndex;
    if (fromIndex < newIndex) {
      newIndex -= 1;
    }
    if (newIndex < 0) newIndex = 0;
    if (newIndex > players.length - 1) newIndex = players.length - 1;

    final result = List<String>.from(players);
    final moved = result.removeAt(fromIndex);
    result.insert(newIndex, moved);
    return result;
  }

  /// Winning player slot index for adjacent pair starting at [leftCastleIndex].
  static int? winningPlayerIndexForPair(int? leftCastleIndex, int castleCount) {
    if (leftCastleIndex == null || castleCount < 3) return null;
    if (leftCastleIndex < 0 || leftCastleIndex >= castleCount) return null;
    return leftCastleIndex;
  }
}
