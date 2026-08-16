import 'package:btcc/src/app/app_widget.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/castle/castle_list_item.dart';
import 'package:btcc/src/widgets/game/player_list_item.dart';
import 'package:flutter/material.dart';

enum _EntryKind { castle, player }

class _Entry {
  final _EntryKind kind;
  final int index;
  _Entry.castle(this.index) : kind = _EntryKind.castle;
  _Entry.player(this.index) : kind = _EntryKind.player;
}

class EditableGameList extends StatefulWidget {
  final Game game;
  final DeleteCastleCallback deleteCallback;
  final void Function(List<int> castlePermutation) rearrangedCastlesCallback;
  final void Function(List<String> newPlayerOrder) rearrangedPlayersCallback;
  final void Function(int playerIndex) renamePlayerCallback;
  final void Function(int playerIndex)? deletePlayerCallback;
  final void Function(Castle castle) openCastleCallback;
  final void Function(Castle castle)? renameCastleCallback;
  final void Function(Castle castle)? editCastleCallback;
  final Color Function(Castle castle)? getCastleColorCallback;

  EditableGameList({
    super.key,
    required this.game,
    required this.deleteCallback,
    required this.rearrangedCastlesCallback,
    required this.rearrangedPlayersCallback,
    required this.renamePlayerCallback,
    this.deletePlayerCallback,
    required this.openCastleCallback,
    this.renameCastleCallback,
    this.editCastleCallback,
    this.getCastleColorCallback,
  });

  @override
  State<EditableGameList> createState() => _EditableGameListState();
}

class _EditableGameListState extends State<EditableGameList> {
  /// While any list item is dragged, castles collapse to header-only.
  bool _reordering = false;

  List<_Entry> _buildEntries() {
    final castles = widget.game.castles;
    final players = widget.game.playerNames;
    final entries = <_Entry>[];
    final slotCount = castles.length;

    for (var i = 0; i < slotCount; i++) {
      entries.add(_Entry.castle(i));
      if (i < players.length) {
        entries.add(_Entry.player(i));
      }
    }
    for (var i = slotCount; i < players.length; i++) {
      entries.add(_Entry.player(i));
    }
    return entries;
  }

  void _onReorder(int oldIndex, int newIndex) {
    final entries = _buildEntries();
    if (oldIndex < 0 || oldIndex >= entries.length) return;
    if (newIndex > entries.length) newIndex = entries.length;
    if (oldIndex < newIndex) newIndex -= 1;

    final moved = entries.removeAt(oldIndex);
    entries.insert(newIndex.clamp(0, entries.length), moved);

    final castleOrder = entries
        .where((e) => e.kind == _EntryKind.castle)
        .map((e) => e.index)
        .toList();
    final playerOrder = entries
        .where((e) => e.kind == _EntryKind.player)
        .map((e) => e.index)
        .toList();

    final originalPlayers = widget.game.playerNames.toList();

    bool castlesChanged = false;
    for (var i = 0; i < castleOrder.length; i++) {
      if (castleOrder[i] != i) {
        castlesChanged = true;
        break;
      }
    }
    if (castlesChanged) {
      widget.rearrangedCastlesCallback(castleOrder);
    }

    final newPlayerNames = playerOrder.map((i) => originalPlayers[i]).toList();
    bool playersChanged = false;
    for (var i = 0; i < newPlayerNames.length; i++) {
      if (newPlayerNames[i] != originalPlayers[i]) {
        playersChanged = true;
        break;
      }
    }
    if (playersChanged) {
      widget.rearrangedPlayersCallback(newPlayerNames);
    }
  }

  void _shiftCastle(int castleIndex, int delta) {
    final count = widget.game.castles.length;
    final target = castleIndex + delta;
    if (target < 0 || target >= count) return;

    final permutation = List<int>.generate(count, (i) => i);
    permutation[castleIndex] = target;
    permutation[target] = castleIndex;
    widget.rearrangedCastlesCallback(permutation);
  }

  void _setReordering(bool value) {
    if (_reordering == value) return;
    setState(() => _reordering = value);
  }

  Widget _castleTile(Castle castle, int castleIndex, {required bool headerOnly}) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: CastleListItem(
        castle: castle,
        deleteCallback: widget.deleteCallback,
              color: widget.getCastleColorCallback?.call(castle) ?? AppColors.card,
        headerOnly: headerOnly,
        onOpen: () => widget.openCastleCallback(castle),
        onRename: widget.renameCastleCallback == null
            ? null
            : () => widget.renameCastleCallback!(castle),
        onEdit: widget.editCastleCallback == null
            ? null
            : () => widget.editCastleCallback!(castle),
        onMoveUp: castleIndex > 0
            ? () => _shiftCastle(castleIndex, -1)
            : null,
        onMoveDown: castleIndex < widget.game.castles.length - 1
            ? () => _shiftCastle(castleIndex, 1)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final entries = _buildEntries();
    final winningPlayer = game.getWinningPlayerIndex();
    final slotCount = game.castles.length;
    final hasBench = game.playerNames.length > slotCount;

    if (entries.isEmpty) {
      return const Center(
        child: Text('Add a castle to get started'),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: true,
      onReorder: _onReorder,
      onReorderStart: (_) => _setReordering(true),
      onReorderEnd: (_) => _setReordering(false),
      proxyDecorator: (child, index, animation) {
        // Drag proxy is captured at lift time (often still expanded). Rebuild
        // castles as header-only so the moving card matches the collapsed list.
        Widget feedback = child;
        if (index >= 0 && index < entries.length) {
          final entry = entries[index];
          if (entry.kind == _EntryKind.castle) {
            feedback = _castleTile(
              game.castles[entry.index],
              entry.index,
              headerOnly: true,
            );
          }
        }

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(animation.value);
            return Material(
              elevation: 8 + 8 * t,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Color.lerp(
                      Colors.white54,
                      Colors.white,
                      t,
                    )!,
                    width: 2 + t,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35 * t),
                      blurRadius: 12 * t,
                      offset: Offset(0, 4 * t),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: feedback,
        );
      },
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final showBenchHeader = hasBench &&
            entry.kind == _EntryKind.player &&
            entry.index == slotCount;

        if (entry.kind == _EntryKind.castle) {
          final castle = game.castles[entry.index];
          return KeyedSubtree(
            key: ValueKey('castle-${castle.hiveCastle!.key}'),
            child: _castleTile(
              castle,
              entry.index,
              headerOnly: _reordering,
            ),
          );
        }

        final isBench = entry.index >= slotCount;
        return Padding(
          key: ValueKey(
              'player-${entry.index}-${game.playerNames[entry.index]}'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBenchHeader)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6, top: 8),
                  child: Text(
                    'Extra players',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ),
              PlayerListItem(
                name: game.playerNames[entry.index],
                score: isBench ? null : game.getPlayerScore(entry.index),
                primaryCastleDirection: isBench
                    ? null
                    : game.getPlayerPrimaryCastleDirection(entry.index),
                isWinner: winningPlayer == entry.index,
                isBench: isBench,
                onRename: () => widget.renamePlayerCallback(entry.index),
                onDelete: isBench && widget.deletePlayerCallback != null
                    ? () => widget.deletePlayerCallback!(entry.index)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
