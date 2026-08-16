import 'package:btcc/src/state/data_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'game_list_item.dart';

class GameList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Consumer<DataStore>(
        builder: (_, store, child) => LayoutBuilder(
          builder: (context, constraints) {
            // Consistent card slots: about one third of the scroll area each.
            final cardExtent = constraints.maxHeight / 3;
            return ListView.builder(
              itemCount: store.games.length,
              itemExtent: cardExtent,
              itemBuilder: (_, int index) => Padding(
                padding: const EdgeInsets.all(4),
                child: GameListItem(
                  game: store.games[index],
                  deleteCallback: (game) async {
                    await store.deleteGame(game.hiveGame);
                  },
                ),
              ),
            );
          },
        ),
      );
}
