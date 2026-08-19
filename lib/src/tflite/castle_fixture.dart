import 'dart:convert';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/cell_guess_info.dart';
import 'package:btcc/src/tflite/cell_guess_remap.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/token_tile_grid.dart';

/// Golden occupancy + identity for a debug castle photo.
///
/// Coordinates are throne-relative: throne left cell is `[0, 0]`, `x` increases
/// right, `y` increases down. The throne's placeholder cell is occupied but
/// omitted from [labels] (it is implied by the 2-wide throne).
///
/// Bonus cards and royal attendants are listed separately — they live on the
/// token strip, not in the room lattice.
class CastleFixture {
  final String image;
  final String source;
  final int expectedRooms;
  final List<List<int>> occupied;
  final Map<String, String> labels;
  final List<String> bonus;
  final List<String> attendants;
  /// Debug scan confidence keyed like [labels] (`"gx,gy"`).
  final Map<String, CellGuessInfo> scan;

  const CastleFixture({
    required this.image,
    required this.source,
    required this.expectedRooms,
    required this.occupied,
    required this.labels,
    this.bonus = const [],
    this.attendants = const [],
    this.scan = const {},
  });

  static const String sourceAsset = 'asset';
  static const String sourcePhoto = 'photo';

  bool get fromAsset => source == sourceAsset;

  String get jsonFileName {
    final stem = _stem(image);
    return '$stem.json';
  }

  static String _stem(String filename) {
    final slash = filename.replaceAll('\\', '/').split('/').last;
    final dot = slash.lastIndexOf('.');
    if (dot <= 0) return slash;
    return slash.substring(0, dot);
  }

  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'image': image,
      'source': source,
      'expectedRooms': expectedRooms,
      'occupied': occupied,
      'labels': labels,
      'bonus': bonus,
      'attendants': attendants,
    };
    if (scan.isNotEmpty) {
      final keys = scan.keys.toList()..sort();
      json['scan'] = {
        for (final key in keys) key: scan[key]!.toJson(),
      };
    }
    return json;
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory CastleFixture.fromJson(Map json) {
    final occupiedRaw = json['occupied'] as List<dynamic>? ?? const [];
    final labelsRaw = json['labels'] as Map<dynamic, dynamic>? ?? const {};
    return CastleFixture(
      image: json['image'] as String? ?? '',
      source: json['source'] as String? ?? sourcePhoto,
      expectedRooms: (json['expectedRooms'] as num?)?.toInt() ?? 0,
      occupied: [
        for (final row in occupiedRaw)
          [
            for (final n in row as List<dynamic>) (n as num).toInt(),
          ],
      ],
      labels: {
        for (final e in labelsRaw.entries) e.key.toString(): e.value.toString(),
      },
      bonus: [
        for (final v in json['bonus'] as List<dynamic>? ?? const [])
          v.toString(),
      ],
      attendants: [
        for (final v in json['attendants'] as List<dynamic>? ?? const [])
          v.toString(),
      ],
      scan: _scanFromJson(json['scan']),
    );
  }

  static Map<String, CellGuessInfo> _scanFromJson(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, CellGuessInfo>{};
    for (final e in raw.entries) {
      final value = e.value;
      if (value is Map) {
        out[e.key.toString()] = CellGuessInfo.fromJson(value);
      }
    }
    return out;
  }

  /// Build a fixture from an edited castle grid.
  ///
  /// [imageFileName] is the bundled asset basename when [fromAsset] is true,
  /// or the filename to write when exporting a camera/gallery photo.
  factory CastleFixture.fromCastle(
    Castle castle, {
    required String imageFileName,
    required bool fromAsset,
  }) {
    final extracted = TokenTileGrid.extractTokenTiles(
      castle.castleTiles,
      getEmpty: () => Empty(),
    );
    final structural = extracted.structural;
    final origin = _throneOrigin(structural);

    final occupied = <List<int>>[];
    final labels = <String, String>{};

    for (var i = 0; i < structural.items.length; i++) {
      final tile = structural.items[i];
      if (tile.isEmpty()) continue;
      final x = i % structural.width;
      final y = i ~/ structural.width;
      final gx = x - origin.$1;
      final gy = y - origin.$2;
      occupied.add([gx, gy]);
      if (tile.isPlaceholder()) continue;
      final label = labelNameFromTile(tile);
      if (label != null) {
        labels['$gx,$gy'] = label;
      }
    }

    occupied.sort((a, b) {
      final dy = a[1].compareTo(b[1]);
      if (dy != 0) return dy;
      return a[0].compareTo(b[0]);
    });

    final bonus = <String>[];
    final attendants = <String>[];
    for (final token in extracted.tokens) {
      final name = labelNameFromTile(token);
      if (name == null) continue;
      if (token.isBonusCard()) {
        bonus.add(name);
      } else if (token.isRoyalAttendant()) {
        attendants.add(name);
      }
    }

    return CastleFixture(
      image: imageFileName.replaceAll('\\', '/').split('/').last,
      source: fromAsset ? sourceAsset : sourcePhoto,
      expectedRooms: TfliteHelper.countPlacedRoomTiles(structural),
      occupied: occupied,
      labels: labels,
      bonus: bonus,
      attendants: attendants,
      scan: {
        for (final e in cellGuessesToThroneMap(
          castle.castleTiles,
          castle.cellGuesses,
        ).entries)
          e.key: CellGuessInfo.fromJson(e.value),
      },
    );
  }

  /// Compare this golden to [actual] (typically from a Scan conversion).
  CastleFixtureDiff diff(CastleFixture actual) {
    String cellKey(List<int> c) => '${c[0]},${c[1]}';
    final expOcc = {for (final c in occupied) cellKey(c)};
    final actOcc = {for (final c in actual.occupied) cellKey(c)};
    final missingOccupied = (expOcc.difference(actOcc).toList()..sort());
    final extraOccupied = (actOcc.difference(expOcc).toList()..sort());

    final wrongLabels = <String, String>{};
    final missingLabels = <String>[];
    for (final e in labels.entries) {
      final got = actual.labels[e.key];
      if (got == null) {
        missingLabels.add(e.key);
      } else if (got != e.value) {
        wrongLabels[e.key] = '${e.value} → $got';
      }
    }

    List<String> bagDiff(List<String> a, List<String> b) {
      final remaining = List<String>.from(b);
      final missing = <String>[];
      for (final item in a) {
        if (!remaining.remove(item)) missing.add(item);
      }
      return missing;
    }

    return CastleFixtureDiff(
      expectedRooms: expectedRooms,
      actualRooms: actual.expectedRooms,
      missingOccupied: missingOccupied,
      extraOccupied: extraOccupied,
      missingLabels: missingLabels..sort(),
      wrongLabels: wrongLabels,
      missingBonus: bagDiff(bonus, actual.bonus),
      extraBonus: bagDiff(actual.bonus, bonus),
      missingAttendants: bagDiff(attendants, actual.attendants),
      extraAttendants: bagDiff(actual.attendants, attendants),
    );
  }

  static (int, int) _throneOrigin(GridList<Tile> grid) {
    for (var i = 0; i < grid.items.length; i++) {
      if (grid.items[i].isThroneRoom()) {
        return (i % grid.width, i ~/ grid.width);
      }
    }
    return (0, 0);
  }
}

class CastleFixtureDiff {
  final int expectedRooms;
  final int actualRooms;
  final List<String> missingOccupied;
  final List<String> extraOccupied;
  final List<String> missingLabels;
  final Map<String, String> wrongLabels;
  final List<String> missingBonus;
  final List<String> extraBonus;
  final List<String> missingAttendants;
  final List<String> extraAttendants;

  const CastleFixtureDiff({
    required this.expectedRooms,
    required this.actualRooms,
    required this.missingOccupied,
    required this.extraOccupied,
    required this.missingLabels,
    required this.wrongLabels,
    required this.missingBonus,
    required this.extraBonus,
    required this.missingAttendants,
    required this.extraAttendants,
  });

  int get shapeErrors =>
      (expectedRooms == actualRooms ? 0 : 1) +
      missingOccupied.length +
      extraOccupied.length;

  int get identityErrors =>
      missingLabels.length +
      wrongLabels.length +
      missingBonus.length +
      extraBonus.length +
      missingAttendants.length +
      extraAttendants.length;

  bool get isPerfect => shapeErrors == 0 && identityErrors == 0;

  @override
  String toString() {
    final lines = <String>[
      'rooms $actualRooms/$expectedRooms',
      if (missingOccupied.isNotEmpty) 'missing occupied: $missingOccupied',
      if (extraOccupied.isNotEmpty) 'extra occupied: $extraOccupied',
      if (missingLabels.isNotEmpty) 'missing labels: $missingLabels',
      if (wrongLabels.isNotEmpty) 'wrong labels: $wrongLabels',
      if (missingBonus.isNotEmpty) 'missing bonus: $missingBonus',
      if (extraBonus.isNotEmpty) 'extra bonus: $extraBonus',
      if (missingAttendants.isNotEmpty) 'missing attendants: $missingAttendants',
      if (extraAttendants.isNotEmpty) 'extra attendants: $extraAttendants',
    ];
    if (isPerfect) return 'perfect';
    return lines.join('\n');
  }
}

/// Detector [TileLabels] name for a placed tile, including copy variants
/// (Fountain2, BallRoomPerDownstairs2, Jester2, …).
String? labelNameFromTile(Tile tile) {
  final label = labelFromTileId(tile.id);
  return label?.name;
}

TileLabels? labelFromTileId(TileId id) {
  _ensureIdToLabel();
  return _idToLabel![id];
}

Map<TileId, TileLabels>? _idToLabel;

void _ensureIdToLabel() {
  if (_idToLabel != null) return;
  final map = <TileId, TileLabels>{};
  final helper = TileHelper();
  for (final label in TileLabels.values) {
    try {
      map[helper.getTileIdFromLabel(label)] = label;
    } catch (_) {
      // Some enum values have no tile mapping.
    }
  }
  for (final e in _copyAliases.entries) {
    map[e.key] = e.value;
  }
  _idToLabel = map;
}

const _copyAliases = <TileId, TileLabels>{
  TileId.Fountain2: TileLabels.FOUNTAIN,
  TileId.Fountain3: TileLabels.FOUNTAIN,
  TileId.Fountain4: TileLabels.FOUNTAIN,
  TileId.Fountain5: TileLabels.FOUNTAIN,
  TileId.Tower2: TileLabels.TOWER,
  TileId.Tower3: TileLabels.TOWER,
  TileId.Tower4: TileLabels.TOWER,
  TileId.Tower5: TileLabels.TOWER,
  TileId.GrandFoyer2: TileLabels.GRAND_FOYER,
  TileId.GrandFoyer3: TileLabels.GRAND_FOYER,
  TileId.GrandFoyer4: TileLabels.GRAND_FOYER,
  TileId.GrandFoyer5: TileLabels.GRAND_FOYER,
  TileId.BallRoomPerActivity2: TileLabels.BRA,
  TileId.BallRoomPerCorridor2: TileLabels.BRC,
  TileId.BallRoomPerFood2: TileLabels.BRF,
  TileId.BallRoomPerDownstairs2: TileLabels.BRD,
  TileId.BallRoomPerSleeping2: TileLabels.BRS,
  TileId.BallRoomPerOutdoor2: TileLabels.BRO,
  TileId.BallRoomPerLiving2: TileLabels.BRL,
  TileId.BallRoomPerUtility2: TileLabels.BRU,
  TileId.RoyalAttendantJester2: TileLabels.RAT,
  TileId.RoyalAttendantKnight2: TileLabels.RAS,
  TileId.RoyalAttendantPainter2: TileLabels.RAP,
  TileId.RoyalAttendantTaylor2: TileLabels.RAM,
};
