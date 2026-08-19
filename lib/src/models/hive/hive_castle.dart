import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:btcc/src/models/exports.dart';

part 'hive_castle.g.dart';

@HiveType(typeId: 1)
class HiveCastle extends HiveObject {

  @HiveField(0)
  List<TileId>? tiles;

  @HiveField(1)
  int? tileWidth;

  @HiveField(2)
  String? imagePath;
  
  @HiveField(3)
  DateTime? created;
  
  @HiveField(4)
  DateTime? updated;

  @HiveField(5)
  String? title;

  /// Bundled debug photo basename (`20260816_044725.jpg`), or null if captured.
  @HiveField(6)
  String? debugAssetName;

  /// Debug-only JSON of throne-relative scan confidence (`"gx,gy"` keys).
  /// Release builds never write this field.
  @HiveField(7)
  String? scanGuessJson;

  /// Debug-only golden JSON basename this castle's scan export should reference
  /// (`TBD.json` until a fixture is exported, then the fixture basename).
  @HiveField(8)
  String? debugGoldenJson;

  HiveCastle({
    this.tiles,
    this.tileWidth,
    this.imagePath,
    this.created,
    this.updated,
    this.title,
    this.debugAssetName,
    this.scanGuessJson,
    this.debugGoldenJson,
  });

  HiveCastle.fromCastle(Castle castle) {
    this.tileWidth = castle.castleTiles.width;
    this.tiles = castle.castleTiles.items.map((e) => e.id).toList();
    this.imagePath = castle.hiveCastle == null ? "" : castle.hiveCastle!.imagePath;
    this.created = castle.hiveCastle == null ? DateTime.now() : castle.hiveCastle!.created;
    this.updated = DateTime.now();
    this.title = castle.title;
    this.debugAssetName = castle.hiveCastle?.debugAssetName;
  }

  @override
  String toString() => jsonEncode(toMap());
  Map toMap() => {
    'tiles': tiles.toString(),
    'tileWidth': tileWidth,
    'imagePath': imagePath,
    'created': created.toString(),
    'updated': updated.toString(),
    'title': title,
    'debugAssetName': debugAssetName,
    'scanGuessJson': scanGuessJson,
    'debugGoldenJson': debugGoldenJson,
  };
}
