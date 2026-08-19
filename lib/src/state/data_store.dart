import 'dart:collection';
import 'dart:io';

import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/player_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/utils/debug_castle_assets.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

class DataStore extends ChangeNotifier {

  String _castleBoxKey = 'castleBox';
  late Box<HiveCastle> _castleBox;
  String _gameBoxKey = 'gameBox';
  late Box<HiveGame> _gameBox;

  List<HiveGame> _storedGames = [];
  UnmodifiableListView<Game> get games {
    var hiveGames = _storedGames.map((e) => Game.fromHiveGame(e)).toList();
    if (!kDebugMode) {
      hiveGames.removeWhere(
        (g) => DebugCastleAssets.isDebugGameTitle(g.hiveGame.title),
      );
    }
    hiveGames.sort((a, b) {
      if (kDebugMode) {
        final aDebug = DebugCastleAssets.isDebugGameTitle(a.hiveGame.title);
        final bDebug = DebugCastleAssets.isDebugGameTitle(b.hiveGame.title);
        if (aDebug != bDebug) return aDebug ? -1 : 1;
      }
      return b.hiveGame.created!.compareTo(a.hiveGame.created!);
    });
    return new UnmodifiableListView(hiveGames);
  }
    

  final GetDirCallback _getDir;
  late String _imagesDirPath;
  String get imagesTempPath => _imagesDirPath;

  DataStore(this._getDir) {
    _init();
  }

  Future<void> _init() async {
    String str = await _getDir();
    _imagesDirPath = str;
    notifyListeners();

    var dataDir = await getApplicationDocumentsDirectory();
    Hive.init(dataDir.path);
    Hive.registerAdapter(HiveCastleAdapter());
    Hive.registerAdapter(TileIdAdapter());
    Hive.registerAdapter(HiveGameAdapter());

    _castleBox = await Hive.openBox<HiveCastle>(_castleBoxKey);

    _gameBox = await Hive.openBox<HiveGame>(_gameBoxKey);
    _storedGames = _gameBox.values.toList();

    if (kDebugMode) {
      await ensureDebugGame();
    }

    notifyListeners();

    await _cleanUpImagesNotAssociatedWithCastles();
  }

  /// Debug-only fixture lab. Created once; pinned at the top of the game list.
  Future<Game> ensureDebugGame() async {
    for (final existing in _storedGames) {
      if (DebugCastleAssets.isDebugGameTitle(existing.title)) {
        return Game.fromHiveGame(existing);
      }
    }
    return createAndPersistGame(title: DebugCastleAssets.gameTitle);
  }

  Future<void> _cleanUpImagesNotAssociatedWithCastles() async {
    if (kIsWeb || Platform.isWindows) {
      return;
    }

    var dir = new Directory(imagesTempPath);
    var exists = await dir.exists();
    if (!exists) {
      return;
    }

    var entities = dir.listSync();

    for (var game in _storedGames) {
      for (var castle in game.castles ?? []) {
        entities.removeWhere((element) => element.path == castle.imagePath);
      }
    }

    for (var entity in entities) {
      log('Deleting ${entity.path}');
      await entity.delete();
    }
  }
  
  Future<void> deleteAllData() async {
    while (_storedGames.isNotEmpty) {
      var game = _storedGames.removeAt(0);
      await deleteGame(game);
    }

    notifyListeners();
  }

  Future<void> addCastle(HiveCastle castle) async {
    await _castleBox.add(castle);
    notifyListeners();
  }

  Future<void> deleteCastle(HiveCastle castle) async {
    if (castle.imagePath != null && castle.imagePath != "") {
      final file = File(castle.imagePath!);
      if (await file.exists()) {
        await file.delete();
      }
      else {
        log('Tried to delete an image that should exist but doesnt');
      }
    }

    await _castleBox.delete(castle.key);
    notifyListeners();
  }

  Future<void> deleteGame(HiveGame game) async {
    (game.castles ?? []).forEach((element) async {
      await deleteCastle(element);
    });
    await _gameBox.delete(game.key);
    _storedGames.remove(game);
    notifyListeners();
  }

  String nextCastleTitle(Game game) {
    final titles = (game.hiveGame.castles ?? []).map((c) => c.title as String?);
    return PlayerHelper.nextCastleTitle(titles);
  }

  Future<void> _syncPlayersForCastleCount(HiveGame game) async {
    final slotCount = game.castles?.length ?? 0;
    final current = List<String>.from(game.playerNames ?? const []);
    final synced = PlayerHelper.ensureSlotPlayers(current, slotCount);
    game.playerNames = synced;
    game.updated = DateTime.now();
    if (game.isInBox) {
      await game.save();
    }
  }

  Future<Game> createAndPersistGame({String? title}) async {
    var now = DateTime.now();
    var castles = HiveList<HiveCastle>(_castleBox);
    var game = HiveGame(
      created: now,
      updated: now,
      castles: castles,
      title: (title == null || title.trim().isEmpty) ? null : title.trim(),
      playerNames: <String>[],
    );

    await _gameBox.add(game);
    _storedGames.add(game);
    notifyListeners();
    return Game.fromHiveGame(game);
  }

  /// Creates an unsaved in-memory game (legacy). Prefer [createAndPersistGame].
  HiveGame createNewGame({String? title}) {
    var now = DateTime.now();

    var castles = new HiveList<HiveCastle>(_castleBox);

    var game = new HiveGame(
      created: now,
      updated: now,
      castles: castles,
      title: (title == null || title.trim().isEmpty) ? null : title.trim(),
      playerNames: <String>[],
    );

    return game;
  }

  Future<void> updateGameTitle(HiveGame game, String title) async {
    game.title = title.trim().isEmpty ? null : title.trim();
    game.updated = DateTime.now();
    if (game.isInBox) {
      await game.save();
    }
    notifyListeners();
  }

  Future<void> updateCastleTitle(HiveCastle castle, String title) async {
    castle.title = title.trim().isEmpty ? 'Castle' : title.trim();
    castle.updated = DateTime.now();
    await castle.save();
    notifyListeners();
  }

  Future<Game> updateCastleInGame(Castle castle, Game game) async {
    final hiveCastle = castle.hiveCastle;
    if (hiveCastle == null) {
      throw StateError('Cannot update a castle that is not persisted');
    }

    hiveCastle.tileWidth = castle.castleTiles.width;
    hiveCastle.tiles = castle.castleTiles.items.map((e) => e.id).toList();
    hiveCastle.updated = DateTime.now();
    if (castle.title.isNotEmpty) {
      hiveCastle.title = castle.title;
    }
    if (castle.hiveCastle?.debugAssetName != null) {
      hiveCastle.debugAssetName = castle.hiveCastle!.debugAssetName;
    }
    await hiveCastle.save();

    game.hiveGame.updated = DateTime.now();
    await game.hiveGame.save();
    notifyListeners();
    return game;
  }

  Future<void> updatePlayerNames(HiveGame game, List<String> names) async {
    game.playerNames = List<String>.from(names);
    game.updated = DateTime.now();
    if (game.isInBox) {
      await game.save();
    }
    notifyListeners();
  }

  Future<void> renamePlayer(HiveGame game, int index, String name) async {
    final names = List<String>.from(game.playerNames ?? const []);
    if (index < 0 || index >= names.length) return;
    names[index] = name.trim().isEmpty ? PlayerHelper.nextPlayerName(names) : name.trim();
    await updatePlayerNames(game, names);
  }

  Future<void> addPlayer(HiveGame game) async {
    final names = List<String>.from(game.playerNames ?? const []);
    names.add(PlayerHelper.nextPlayerName(names));
    await updatePlayerNames(game, names);
  }

  Future<void> deletePlayer(HiveGame game, int index) async {
    final names = List<String>.from(game.playerNames ?? const []);
    if (index < 0 || index >= names.length) return;
    names.removeAt(index);
    await updatePlayerNames(game, names);
  }

  Future<void> movePlayer(HiveGame game, int fromIndex, int toIndex) async {
    final names = List<String>.from(game.playerNames ?? const []);
    final moved = PlayerHelper.cascadeMove(names, fromIndex, toIndex);
    await updatePlayerNames(game, moved);
  }

  Future<Game> addCastleToGame(Castle castle, String imagePath, Game game, 
    int numPicturesTaken, {String? debugAssetName}) 
  async {
    var hiveCastle = new HiveCastle.fromCastle(castle);
    if (hiveCastle.title == null || hiveCastle.title == '') {
      hiveCastle.title = nextCastleTitle(game);
    }
    hiveCastle.imagePath = imagePath;
    hiveCastle.debugAssetName = debugAssetName;

    addCastle(hiveCastle);
    game.hiveGame.castles!.add(hiveCastle);

    if (!game.hiveGame.isInBox) {
      _gameBox.add(game.hiveGame);
      _storedGames.add(game.hiveGame);
    }

    // Each new castle gets a matching player slot.
    final names = List<String>.from(game.hiveGame.playerNames ?? const []);
    names.add(PlayerHelper.nextPlayerName(names));
    game.hiveGame.playerNames = names;
    await _syncPlayersForCastleCount(game.hiveGame);
    await game.hiveGame.save();
    notifyListeners();

    return game;
  }

  Future<void> deleteCastleFromGame(Castle castle, Game game) async {
    await deleteCastle(castle.hiveCastle!);
    await _syncPlayersForCastleCount(game.hiveGame);
    if (game.hiveGame.isInBox) {
      game.hiveGame.updated = DateTime.now();
      await game.hiveGame.save();
    }
    notifyListeners();
  }

  Future<void> updateOrderOfCastles(HiveGame game, int oldIndex, int newIndex) async {
    List<HiveCastle> copy = <HiveCastle>[];
    copy.addAll(game.castles ?? []);

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    var castle = copy.removeAt(oldIndex);
    if (newIndex > copy.length) {
      copy.add(castle);
    }
    else {
      copy.insert(newIndex, castle);
    }

    game.castles!.clear();
    game.castles!.addAll(copy);

    await game.save();
    notifyListeners();
  }

  /// Reorders castles to match [newOrder], where values are previous indices.
  Future<void> reorderCastlesByPermutation(HiveGame game, List<int> newOrder) async {
    final current = List<HiveCastle>.from(game.castles ?? const []);
    if (newOrder.length != current.length) return;

    final reordered = <HiveCastle>[];
    for (final i in newOrder) {
      if (i < 0 || i >= current.length) return;
      reordered.add(current[i]);
    }

    game.castles!.clear();
    game.castles!.addAll(reordered);
    game.updated = DateTime.now();
    await game.save();
    notifyListeners();
  }

}
