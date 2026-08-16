import 'package:btcc/src/app/app_widget.dart';
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

  void _onLongPress(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AsyncConfirmationDialog(
        confirmationText:
            'Are you sure you want to delete this game (and all castles with it)?',
        progressText: 'Deleting game...',
        onPressedYes: () async {
          await deleteCallback(game);
          return 'Successfully deleted game!';
        },
      ),
    );
  }

  Widget _getFlexibleCastleView(Castle castle) => Flexible(
        child: Column(
          children: [
            Text(
              castle.hiveCastle?.title ?? castle.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(castle.getScore().toString()),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final grid = castle.castleTiles;
                  const tile = TileWidget.defaultTileWidthHeight;
                  final naturalW = grid.width * tile;
                  final naturalH = grid.height * tile;
                  if (naturalW <= 0 || naturalH <= 0) {
                    return const SizedBox.shrink();
                  }
                  var scale = constraints.maxWidth / naturalW;
                  final scaleH = constraints.maxHeight / naturalH;
                  if (scaleH < scale) scale = scaleH;
                  scale = scale.clamp(0.08, 1.0);
                  return ClipRect(
                    child: Center(
                      child: CastleTilesGrid(
                        grid,
                        scaleWithScreen: false,
                        scalePercentScreenWidth: 0,
                        scale: scale,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pair = game.getWinningCastle();
    final winningPlayerIndex = game.getWinningPlayerIndex();
    final winningPlayerName = winningPlayerIndex == null
        ? null
        : (winningPlayerIndex < game.playerNames.length
            ? game.playerNames[winningPlayerIndex]
            : null);

    return Material(
      elevation: 8.0,
      borderRadius: BorderRadius.circular(20.0),
      color: AppColors.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => NavigationHelper.goToGameEditScreen(
          context,
          game: game,
        ),
        onLongPress: () => _onLongPress(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                game.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                StringHelper.getMonthDayYear(game.hiveGame.created!),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              if (winningPlayerName != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events,
                        color: Colors.green, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Winner: $winningPlayerName',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: pair != null
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _getFlexibleCastleView(pair.key),
                          const SizedBox(width: 10),
                          _getFlexibleCastleView(pair.value),
                        ],
                      )
                    : const Center(
                        child: Text(
                          'Not enough castles to determine a winner',
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
