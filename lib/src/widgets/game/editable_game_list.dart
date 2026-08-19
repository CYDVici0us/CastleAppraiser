import 'package:btcc/src/app/app_widget.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/castle/castle_list_item.dart';
import 'package:btcc/src/widgets/game/player_list_item.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum _EntryKind { castle, player }

class _Entry {
  final _EntryKind kind;
  final int index;
  _Entry.castle(this.index) : kind = _EntryKind.castle;
  _Entry.player(this.index) : kind = _EntryKind.player;
}

class EditableGameList extends StatelessWidget {
  final Game game;
  final bool sorting;
  final DeleteCastleCallback deleteCallback;
  final void Function(List<int> castlePermutation) rearrangedCastlesCallback;
  final void Function(List<String> newPlayerOrder) rearrangedPlayersCallback;
  final void Function(int playerIndex) renamePlayerCallback;
  final void Function(int playerIndex)? deletePlayerCallback;
  final void Function(Castle castle) openCastleCallback;
  final void Function(Castle castle)? renameCastleCallback;
  final void Function(Castle castle)? editCastleCallback;
  final void Function(Castle castle)? exportCastleCallback;
  final Color Function(Castle castle)? getCastleColorCallback;

  const EditableGameList({
    super.key,
    required this.game,
    this.sorting = false,
    required this.deleteCallback,
    required this.rearrangedCastlesCallback,
    required this.rearrangedPlayersCallback,
    required this.renamePlayerCallback,
    this.deletePlayerCallback,
    required this.openCastleCallback,
    this.renameCastleCallback,
    this.editCastleCallback,
    this.exportCastleCallback,
    this.getCastleColorCallback,
  });

  List<_Entry> _buildEntries() {
    final castles = game.castles;
    final players = game.playerNames;
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

  void _onReorderItem(int oldIndex, int newIndex) {
    if (!sorting) return;

    final entries = _buildEntries();
    if (oldIndex < 0 || oldIndex >= entries.length) return;
    if (newIndex < 0 || newIndex > entries.length) return;

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

    final originalPlayers = game.playerNames.toList();

    var castlesChanged = false;
    for (var i = 0; i < castleOrder.length; i++) {
      if (castleOrder[i] != i) {
        castlesChanged = true;
        break;
      }
    }
    if (castlesChanged) {
      rearrangedCastlesCallback(castleOrder);
    }

    final newPlayerNames = playerOrder.map((i) => originalPlayers[i]).toList();
    var playersChanged = false;
    for (var i = 0; i < newPlayerNames.length; i++) {
      if (newPlayerNames[i] != originalPlayers[i]) {
        playersChanged = true;
        break;
      }
    }
    if (playersChanged) {
      rearrangedPlayersCallback(newPlayerNames);
    }
  }

  static const Widget _dragHandleIcon =
      Icon(Icons.drag_handle, color: Colors.white70);

  /// Touch (not long-press) drag on the handle affordance.
  Widget _dragHandle(int index) {
    return ReorderableDragStartListener(
      index: index,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: _dragHandleIcon,
      ),
    );
  }

  Widget _castleTile(
    Castle castle,
    int castleIndex, {
    required int listIndex,
    double? maxGridHeight,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: CastleListItem(
        castle: castle,
        deleteCallback: deleteCallback,
        color: getCastleColorCallback?.call(castle) ?? AppColors.card,
        headerOnly: sorting,
        maxGridHeight: maxGridHeight,
        dragHandle: sorting ? _dragHandle(listIndex) : null,
        onOpen: sorting ? null : () => openCastleCallback(castle),
        onRename: sorting || renameCastleCallback == null
            ? null
            : () => renameCastleCallback!(castle),
        onEdit: sorting || editCastleCallback == null
            ? null
            : () => editCastleCallback!(castle),
        onExport: sorting || exportCastleCallback == null
            ? null
            : () => exportCastleCallback!(castle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();
    final winningPlayer = game.getWinningPlayerIndex();
    final slotCount = game.castles.length;
    final hasBench = game.playerNames.length > slotCount;

    if (entries.isEmpty) {
      return const Center(
        child: Text('Add a castle to get started'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Half the list viewport — between app bar and footer buttons.
        final maxGridHeight =
            sorting ? null : constraints.maxHeight * 0.5;

        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          dragStartBehavior: DragStartBehavior.down,
          onReorderItem: _onReorderItem,
          proxyDecorator: (child, index, animation) {
            Widget feedback = child;
            if (index >= 0 && index < entries.length) {
              final entry = entries[index];
              if (entry.kind == _EntryKind.castle) {
                feedback = _castleTile(
                  game.castles[entry.index],
                  entry.index,
                  listIndex: index,
                  maxGridHeight: maxGridHeight,
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
                        color: Color.lerp(Colors.white54, Colors.white, t)!,
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
                  listIndex: index,
                  maxGridHeight: maxGridHeight,
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
                    primaryCastleDirection: isBench || sorting
                        ? null
                        : game.getPlayerPrimaryCastleDirection(entry.index),
                    isWinner: !sorting && winningPlayer == entry.index,
                    isBench: isBench,
                    dragHandle: sorting ? _dragHandle(index) : null,
                    onRename: sorting
                        ? null
                        : () => renamePlayerCallback(entry.index),
                    onDelete: !sorting &&
                            isBench &&
                            deletePlayerCallback != null
                        ? () => deletePlayerCallback!(entry.index)
                        : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
