import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/string_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/castle/castle_tiles_grid.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart';

import '../async_confirmation_dialog.dart';


class GameListItem extends StatelessWidget {
  final Game game;
  final DeleteGameCallback deleteCallback;

  GameListItem({
    required this.game,
    required this.deleteCallback,
  });

  _onLongPress(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AsyncConfirmationDialog(
        confirmationText: 'Are you sure you want to delete this game (and all castles with it)?',
        progressText: 'Deleting game...',
        onPressedYes: () async {
          await deleteCallback(game);
          return 'Successfully deleted game!';
        },
      )
    );
  }

  _getFlexibleCastleView(BuildContext context, Castle castle) => Flexible(
    child: Column(
      children: [
        Text(castle.hiveCastle?.title ?? castle.title),
        Text(castle.getScore().toString()),
        LayoutBuilder(
          builder: (context, constraints) {
            final grid = castle.castleTiles;
            final scale = constraints.maxWidth /
                (grid.width * TileWidget.defaultTileWidthHeight);
            return CastleTilesGrid(
              grid,
              scaleWithScreen: false,
              scalePercentScreenWidth: 0,
              scale: scale.clamp(0.12, 1.0),
            );
          },
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {

    var pair = game.getWinningCastle();
    final winningPlayerIndex = game.getWinningPlayerIndex();
    final winningPlayerName = winningPlayerIndex == null
        ? null
        : (winningPlayerIndex < game.playerNames.length
            ? game.playerNames[winningPlayerIndex]
            : null);

    List<Widget> children = [
      Text(
        game.title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      Text(
        StringHelper.getMonthDayYear(game.hiveGame.created!),
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
      Container(height:10),
    ];

    if (winningPlayerName != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, color: Colors.green, size: 20),
            const SizedBox(width: 6),
            Text(
              'Winner: $winningPlayerName',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ));
    }

    if (pair != null) {
      var left = pair.key;
      var right = pair.value;

      children.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _getFlexibleCastleView(context, left),
          Container(width:10),
          _getFlexibleCastleView(context, right),
        ],
      ));
    }
    else {
      children.addAll([
        Text('Not enough castles to determine a winner'),
        Container(height: 50),
      ]);
    }

    return Material(
      elevation: 8.0,
      borderRadius: BorderRadius.circular(20.0),
      color: Colors.blueGrey,
      child: InkWell(
        onTap: () => NavigationHelper.goToGameEditScreen(context,
          game: game,
        ),
        onLongPress: () => _onLongPress(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: children,
          ),
        ),
      )
    );
  }

}
