import 'package:btcc/src/screens/about_screen.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/button_padding.dart';
import 'package:btcc/src/widgets/edit_text_dialog.dart';
import 'package:btcc/src/widgets/game/game_list.dart';
import 'package:btcc/src/state/data_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatelessWidget {
  void _showDeleteHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Games'),
        content: const Text(
          'Long-press a game card to delete that game and all of its castles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _addNewGame(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => EditTextDialog(
        confirmationText: 'Name this game',
        onPressedYes: (name) async {
          final store = Provider.of<DataStore>(context, listen: false);
          final game = await store.createAndPersistGame(title: name);
          NavigationHelper.goToGameEditScreen(context, game: game);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const Icon(Icons.home),
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () => _showDeleteHelp(context),
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'Debug ML',
              onPressed: () => NavigationHelper.goToDebugMlScreen(context),
            ),
        ],
      ),
      body: BackgroundContainer(
        child: Column(
          children: [
            Expanded(child: GameList()),
            ButtonPadding(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: double.infinity,
                child: FloatingActionButton.extended(
                  heroTag: 'newgame',
                  icon: const Icon(Icons.add),
                  label: const Text('Add new game'),
                  onPressed: () => _addNewGame(context),
                ),
              ),
            ),
            ButtonPadding(),
          ],
        ),
      ),
    );
  }
}
