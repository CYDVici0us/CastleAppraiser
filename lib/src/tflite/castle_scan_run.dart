import 'dart:convert';

import 'package:btcc/src/tflite/castle_fixture.dart';
import 'package:btcc/src/tflite/cell_guess_info.dart';
import 'package:btcc/src/tflite/cell_guess_remap.dart';
import 'package:btcc/src/models/exports.dart';

/// One detector/grid pass against a [CastleFixture] golden.
///
/// Drop these under `test/fixtures/scans/`. Several runs may share the same
/// [golden] basename. Occupancy and labels here are what this pass produced,
/// not the ground-truth in the golden file.
class CastleScanRun {
  final String golden;
  final DateTime captured;
  final String workflow;
  final int expectedRooms;
  final List<List<int>> occupied;
  final Map<String, String> labels;
  final List<String> bonus;
  final List<String> attendants;
  final Map<String, CellGuessInfo> scan;

  const CastleScanRun({
    required this.golden,
    required this.captured,
    required this.occupied,
    required this.labels,
    this.workflow = workflowGrid,
    this.expectedRooms = 0,
    this.bonus = const [],
    this.attendants = const [],
    this.scan = const {},
  });

  static const String workflowGrid = 'grid';
  static const String workflowScan = 'scan';

  /// Placeholder until a fixture golden is exported; edit or re-export later.
  static const String placeholderGolden = 'TBD.json';

  static String normalizeGoldenName(String raw) {
    var name = raw.trim().replaceAll('\\', '/').split('/').last;
    if (name.isEmpty) return '';
    if (!name.toLowerCase().endsWith('.json')) {
      name = '$name.json';
    }
    return name;
  }

  /// Fixture goldens are `Castle_4_1787107868285.json`, not `Castle_4.json`.
  static final _fixtureGoldenName = RegExp(
    r'^.+_\d{10,}\.json$',
    caseSensitive: false,
  );

  static bool looksLikeFixtureGolden(String raw) {
    final name = normalizeGoldenName(raw);
    return name.isNotEmpty && _fixtureGoldenName.hasMatch(name);
  }

  String get jsonFileName {
    final stem = CastleFixture.stemOf(golden);
    return '${stem}_scan_${captured.millisecondsSinceEpoch}.json';
  }

  Map<String, Object?> toJson() {
    final keys = scan.keys.toList()..sort();
    return {
      'golden': golden,
      'captured': captured.toUtc().toIso8601String(),
      'workflow': workflow,
      'expectedRooms': expectedRooms,
      'occupied': occupied,
      'labels': labels,
      'bonus': bonus,
      'attendants': attendants,
      'scan': {
        for (final key in keys) key: scan[key]!.toJson(),
      },
    };
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory CastleScanRun.fromJson(Map json) {
    final occupiedRaw = json['occupied'] as List<dynamic>? ?? const [];
    final labelsRaw = json['labels'] as Map<dynamic, dynamic>? ?? const {};
    final capturedRaw = json['captured'] as String?;
    return CastleScanRun(
      golden: normalizeGoldenName(json['golden'] as String? ?? ''),
      captured: capturedRaw == null
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.parse(capturedRaw),
      workflow: json['workflow'] as String? ?? workflowGrid,
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
      scan: scanFromJson(json['scan']),
    );
  }

  static Map<String, CellGuessInfo> scanFromJson(Object? raw) {
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

  factory CastleScanRun.fromCastle(
    Castle castle, {
    required String golden,
    DateTime? captured,
    String workflow = workflowGrid,
  }) {
    final fixture = CastleFixture.fromCastle(
      castle,
      imageFileName: normalizeGoldenName(golden),
      fromAsset: false,
    );
    return CastleScanRun(
      golden: normalizeGoldenName(golden),
      captured: captured ?? DateTime.now().toUtc(),
      workflow: workflow,
      expectedRooms: fixture.expectedRooms,
      occupied: fixture.occupied,
      labels: fixture.labels,
      bonus: fixture.bonus,
      attendants: fixture.attendants,
      scan: {
        for (final e in cellGuessesToThroneMap(
          castle.castleTiles,
          castle.cellGuesses,
        ).entries)
          e.key: CellGuessInfo.fromJson(e.value),
      },
    );
  }

  /// Occupancy/identity vs the referenced golden (not confidence).
  CastleFixtureDiff diffGolden(CastleFixture goldenFixture) {
    return goldenFixture.diff(
      CastleFixture(
        image: goldenFixture.image,
        source: goldenFixture.source,
        expectedRooms: expectedRooms,
        occupied: occupied,
        labels: labels,
        bonus: bonus,
        attendants: attendants,
      ),
    );
  }
}
