import 'package:btcc/src/app/app_widget.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/state/camera_store.dart';
import 'package:btcc/src/state/data_store.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/debug_castle_assets.dart';
import 'package:btcc/src/utils/castle_fixture_export.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/builder/tile_picker_sheet.dart';
import 'package:btcc/src/widgets/button_padding.dart';
import 'package:btcc/src/widgets/edit_text_dialog.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:btcc/src/widgets/game/editable_game_list.dart';
import 'package:flutter/foundation.dart';
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
  bool _sorting = false;
  String? _pendingDebugAssetName;

  _GameEditScreenState({this.game});

  bool get _isDebugGame =>
      kDebugMode && DebugCastleAssets.isDebugGameTitle(game?.hiveGame.title);

  @override
  void initState() {
    super.initState();
  }

  Future<void> _addCastle(Castle castle, String imagePath, 
    int numPicturesTaken) async {
    final assetName = _pendingDebugAssetName;
    _pendingDebugAssetName = null;

    if (this.game == null) {
      var store = Provider.of<DataStore>(context, listen: false);
      this.game = await store.createAndPersistGame();
    }

    var store = Provider.of<DataStore>(context, listen: false);
    if (assetName != null && assetName.isNotEmpty) {
      castle.title = DebugCastleAssets.stem(assetName);
    } else {
      castle.title = store.nextCastleTitle(this.game!);
    }
    var updated = await store.addCastleToGame(castle, imagePath, 
      this.game!, numPicturesTaken, debugAssetName: assetName);

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
    if (game == null || _isDebugGame) return;
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

  Future<void> _onBuildCastle() async {
    _pendingDebugAssetName = null;
    final TileId throneId;
    if (kDebugMode) {
      throneId = TileId.ThroneRoomPerCorridorDownstairs;
    } else {
      final chosen = await showThroneRoomPickerDialog(context);
      if (chosen == null || !mounted) return;
      throneId = chosen.id;
    }

    if (!mounted) return;
    NavigationHelper.goToCastleBuilderScreen(
      context,
      castleTiles: TileHelper().getStartingGridList(throneId),
      addCastleCallback: _addCastle,
      gameTitle: game?.title ?? 'New Game',
    );
  }

  void _openCastle(Castle castle) {
    NavigationHelper.goToCastleScreen(
      context,
      castle,
      renameCastleCallback: () => _renameCastle(castle),
      gameTitle: game?.title,
    );
  }

  Widget _getTitle() {
    final gameName = game?.title ?? 'New Game';
    final segments = <String>[
      gameName,
      if (_sorting) 'Sort',
    ];
    return FlowBreadcrumb(
      showHome: true,
      onHomeTap: () => NavigationHelper.popToHome(context),
      segments: segments,
      onSegmentTap: (index) {
        // Game name while sorting → return to castles view.
        if (index == 0 && _sorting) {
          setState(() => _sorting = false);
        }
      },
    );
  }

  void _exitSorting() {
    if (_sorting) setState(() => _sorting = false);
  }

  Color _getCastleItemColor(Castle castle) {
    // Dark blue card so empty cells read as grid gaps, not charcoal slabs.
    return AppColors.card;
  }

  Widget _getCastleList() => EditableGameList(
    game: game ?? Game.fromHiveGame(HiveGame(
      castles: null,
      playerNames: const [],
    )),
    sorting: _sorting,
    rearrangedCastlesCallback: _rearrangedCastles,
    rearrangedPlayersCallback: _rearrangedPlayers,
    deleteCallback: _deleteCastle,
    renamePlayerCallback: _renamePlayer,
    deletePlayerCallback: _deletePlayer,
    openCastleCallback: _openCastle,
    renameCastleCallback: _renameCastle,
    editCastleCallback: _editCastle,
    exportCastleCallback: _isDebugGame ? _exportCastle : null,
    getCastleColorCallback: _getCastleItemColor,
  );

  Future<void> _exportCastle(Castle castle) async {
    try {
      await CastleFixtureExport.share(castle);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export fixture: $e')),
      );
    }
  }

  void _openAddCastle() {
    _pendingDebugAssetName = null;
    if (_isDebugGame) {
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take or pick a photo'),
                subtitle: const Text('Export JSON + image after you fix the map'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _startCameraFlow();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose debug photo'),
                subtitle: const Text(
                    'test/fixtures/castles — export JSON next to the photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _startDebugAssetFlow();
                },
              ),
            ],
          ),
        ),
      );
      return;
    }
    _startCameraFlow();
  }

  void _startCameraFlow() {
    final cameraStore = Provider.of<CameraStore>(context, listen: false);
    NavigationHelper.goToCameraExperience(
      context,
      addCastleCallback: _addCastle,
      numPicturesTaken: 0,
      replace: false,
      cameraTech: cameraStore.cameraTech,
      gameTitle: game?.title ?? 'New Game',
    );
  }

  void _startDebugAssetFlow() {
    NavigationHelper.goToDebugAssetPickerScreen(
      context,
      addCastleCallback: _addCastle,
      gameTitle: game?.title ?? DebugCastleAssets.gameTitle,
      onAssetChosen: (name) => _pendingDebugAssetName = name,
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text(
          'Tap the reorder icon to rearrange castles and players by dragging.\n\n'
          'Players sit between castles (including after the last castle for the wrap-around).\n\n'
          'The winner is marked with a Winner badge: the player between the two highest-scoring adjacent castles.\n\n'
          'Extra players beyond the number of castles appear at the bottom.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomActions() {
    if (_sorting) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            heroTag: 'sorting',
            label: const Text('Finish sorting'),
            icon: const Icon(Icons.check),
            onPressed: _exitSorting,
          ),
        ),
      );
    }

    return Row(
      children: [
        const SizedBox(width: 8),
        FloatingActionButton.extended(
          heroTag: '2',
          label: const Text('Build castle'),
          icon: const Icon(Icons.build),
          onPressed: _onBuildCastle,
        ),
        const Spacer(),
        FloatingActionButton.extended(
          heroTag: '1',
          label: Text(_isDebugGame ? 'Add debug castle' : 'Add Castle'),
          icon: const Icon(Icons.camera_alt),
          onPressed: _openAddCastle,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canReorder = !_sorting &&
        game != null &&
        (game!.castles.length + game!.playerNames.length) > 1;

    return PopScope(
      canPop: !_sorting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_sorting) _exitSorting();
      },
      child: Scaffold(
        appBar: AppBar(
          // Default back arrow: one step up (or exit Sort via PopScope).
          title: _getTitle(),
          actions: [
            if (canReorder)
              IconButton(
                icon: const Icon(Icons.swap_vert),
                tooltip: 'Reorder',
                onPressed: () => setState(() => _sorting = true),
              ),
            if (!_sorting) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: _isDebugGame ? 'Debug game cannot be renamed' : 'Rename game',
                onPressed: game == null || _isDebugGame ? null : _renameGame,
              ),
              IconButton(
                icon: const Icon(Icons.person_add),
                tooltip: 'Add player',
                onPressed: _addPlayer,
              ),
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Help',
                onPressed: () => _showInfoDialog(context),
              ),
            ],
          ],
        ),
        body: BackgroundContainer(
          child: Column(
            children: [
              Expanded(
                child: game == null ||
                        (game!.castles.isEmpty && game!.playerNames.isEmpty)
                    ? Center(
                        child: Text(_isDebugGame
                            ? 'Add a debug castle, fix rooms and tokens, then export'
                            : 'Add a castle or player to get started'),
                      )
                    : _getCastleList(),
              ),
              ButtonPadding(),
              _bottomActions(),
              ButtonPadding(),
            ],
          ),
        ),
      ),
    );
  }
}
