import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/state/camera_store.dart';
import 'package:btcc/src/state/data_store.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/button_padding.dart';
import 'package:btcc/src/widgets/edit_text_dialog.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:btcc/src/widgets/game/editable_game_list.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GameEditScreen extends StatefulWidget {
  final Game? game;
  GameEditScreen({this.game});

  @override
  State createState() => _GameEditScreenState(game: game);
}

class _GameEditScreenState extends State<GameEditScreen> {
  
  Game? game;

  _GameEditScreenState({this.game});

  @override
  void initState() {
    super.initState();
  }

  Future<void> _addCastle(Castle castle, String imagePath, 
    int numPicturesTaken) async {
    if (this.game == null) {
      var store = Provider.of<DataStore>(context, listen: false);
      this.game = await store.createAndPersistGame();
    }

    var store = Provider.of<DataStore>(context, listen: false);
    castle.title = store.nextCastleTitle(this.game!);
    var updated = await store.addCastleToGame(castle, imagePath, 
      this.game!, numPicturesTaken);

    updated.recalculateScores();
    
    setState((){
      game = updated;
    });
  }

  Future<void> _updateCastle(Castle castle) async {
    var store = Provider.of<DataStore>(context, listen: false);
    var updated = await store.updateCastleInGame(castle, game!);
    updated.recalculateScores();
    setState(() {
      game = updated;
    });
  }

  Future<void> _deleteCastle(Castle castle) async {
    var store = Provider.of<DataStore>(context, listen: false);
    await store.deleteCastleFromGame(castle, game!);

    this.game!.recalculateScores();
    setState((){
      game = game;
    });
  }

  Future<void> _rearrangedCastles(List<int> permutation) async {
    var store = Provider.of<DataStore>(context, listen: false);
    await store.reorderCastlesByPermutation(game!.hiveGame, permutation);

    this.game!.recalculateScores();
    setState((){
      game = game;
    });
  }

  Future<void> _rearrangedPlayers(List<String> names) async {
    var store = Provider.of<DataStore>(context, listen: false);
    await store.updatePlayerNames(game!.hiveGame, names);
    setState(() {
      game = game;
    });
  }

  void _renameGame() {
    if (game == null) return;
    showDialog(
      context: context,
      builder: (_) => EditTextDialog(
        confirmationText: 'Name this game',
        defaultText: game!.hiveGame.title ?? '',
        onPressedYes: (str) async {
          var store = Provider.of<DataStore>(context, listen: false);
          await store.updateGameTitle(game!.hiveGame, str);
          setState(() {
            game = game;
          });
        },
      ),
    );
  }

  void _renameCastle(Castle castle) {
    showDialog(
      context: context,
      builder: (_) => EditTextDialog(
        confirmationText: 'Rename castle',
        defaultText: castle.hiveCastle?.title ?? castle.title,
        onPressedYes: (str) async {
          var store = Provider.of<DataStore>(context, listen: false);
          await store.updateCastleTitle(castle.hiveCastle!, str);
          setState(() {
            game = game;
          });
        },
      ),
    );
  }

  void _renamePlayer(int index) {
    showDialog(
      context: context,
      builder: (_) => EditTextDialog(
        confirmationText: 'Rename player',
        defaultText: game!.playerNames[index],
        onPressedYes: (str) async {
          var store = Provider.of<DataStore>(context, listen: false);
          await store.renamePlayer(game!.hiveGame, index, str);
          setState(() {
            game = game;
          });
        },
      ),
    );
  }

  Future<void> _deletePlayer(int index) async {
    if (game == null) return;
    var store = Provider.of<DataStore>(context, listen: false);
    await store.deletePlayer(game!.hiveGame, index);
    setState(() {
      game = game;
    });
  }

  Future<void> _addPlayer() async {
    if (game == null) {
      var store = Provider.of<DataStore>(context, listen: false);
      game = await store.createAndPersistGame();
    }
    var store = Provider.of<DataStore>(context, listen: false);
    await store.addPlayer(game!.hiveGame);
    setState(() {
      game = game;
    });
  }

  void _editCastle(Castle castle) {
    NavigationHelper.goToCastleBuilderScreen(
      context,
      castleTiles: castle.castleTiles,
      imagePath: castle.hiveCastle?.imagePath,
      existingCastle: castle,
      updateCastleCallback: (updated) async {
        updated.hiveCastle = castle.hiveCastle;
        updated.title = castle.hiveCastle?.title ?? castle.title;
        await _updateCastle(updated);
      },
      gameTitle: game?.title,
    );
  }

  void _openCastle(Castle castle) {
    NavigationHelper.goToCastleScreen(
      context,
      castle,
      deleteCastleCallback: _deleteCastle,
      editCastleCallback: () => _editCastle(castle),
      renameCastleCallback: () => _renameCastle(castle),
      gameTitle: game?.title,
    );
  }

  Widget _getTitle() {
    if (game == null) {
      return const FlowBreadcrumb(segments: ['New Game']);
    }
    return FlowBreadcrumb(
      segments: [game!.title],
      onFirstSegmentTap: _renameGame,
    );
  }

  Color _getCastleItemColor(Castle castle) {
    return Colors.blueGrey.shade600;
  }

  Widget _getCastleList() => EditableGameList(
    game: game ?? Game.fromHiveGame(HiveGame(
      castles: null,
      playerNames: const [],
    )),
    rearrangedCastlesCallback: _rearrangedCastles,
    rearrangedPlayersCallback: _rearrangedPlayers,
    deleteCallback: _deleteCastle,
    renamePlayerCallback: _renamePlayer,
    deletePlayerCallback: _deletePlayer,
    openCastleCallback: _openCastle,
    renameCastleCallback: _renameCastle,
    editCastleCallback: _editCastle,
    getCastleColorCallback: _getCastleItemColor,
  );

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(
          'Rearrange castles and players by long pressing to drag and drop.\n\n'
          'Players sit between castles (including after the last castle for the wrap-around).\n\n'
          'The winner is marked with a Winner badge — the player between the two highest-scoring adjacent castles.\n\n'
          'Extra players beyond the number of castles appear at the bottom.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK',
              style: TextStyle(
                color: Colors.blue,
              )
            ),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _getTitle(),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            tooltip: 'Rename game',
            onPressed: game == null ? null : _renameGame,
          ),
          IconButton(
            icon: Icon(Icons.person_add),
            tooltip: 'Add player',
            onPressed: _addPlayer,
          ),
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: () => _showInfoDialog(context),
          )
        ],
      ),
      body: BackgroundContainer(
        child: Column(
          children: [
            Expanded(
              child: game == null || (game!.castles.isEmpty && game!.playerNames.isEmpty)
                  ? const Center(child: Text('Add a castle or player to get started'))
                  : _getCastleList(),
            ),
            ButtonPadding(),
            Row(
              children: [
                Container(width:8),
                FloatingActionButton.extended(
                  heroTag: '2',
                  label: Text('Build castle'),
                  icon: Icon(Icons.build),
                  onPressed: () => NavigationHelper.goToCastleBuilderScreen(context, 
                    castleTiles: TileHelper().getStartingGridList(TileId.ThroneRoomPerCorridorDownstairs),
                    addCastleCallback: _addCastle,
                    gameTitle: game?.title ?? 'New Game',
                  ),
                ),
                Flexible(
                  child: Container(),
                ),
                Consumer<CameraStore>(
                  builder: (_, cameraStore, __) => FloatingActionButton.extended(
                    heroTag: '1',
                    label: Text('Add Castle'),
                    icon: Icon(Icons.camera_alt),
                    onPressed: () => NavigationHelper.goToCameraExperience(
                      context,
                      addCastleCallback: _addCastle,
                      numPicturesTaken: 0,
                      replace: false,
                      cameraTech: cameraStore.cameraTech,
                      gameTitle: game?.title ?? 'New Game',
                    )
                  )
                ),
                Container(width:8),
              ],
            ),
            ButtonPadding(),
          ]
        ),
      )
    );
  }
}
