import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:btcc/src/models/exports.dart';

part 'hive_game.g.dart';

@HiveType(typeId: 3)
class HiveGame extends HiveObject {

  @HiveField(0)
  DateTime? created;

  @HiveField(1)
  DateTime? updated;

  @HiveField(2)
  HiveList<HiveCastle>? castles;

  @HiveField(3)
  String? title;

  @HiveField(4)
  List<String>? playerNames;

  HiveGame({
    this.created,
    this.updated,
    this.castles,
    this.title,
    this.playerNames,
  });

  @override
  String toString() => jsonEncode(toMap());
  Map toMap() => {
    'castles': castles.toString(),
    'created': created.toString(),
    'updated': updated.toString(),
    'title': title,
    'playerNames': playerNames.toString(),
  };
}
