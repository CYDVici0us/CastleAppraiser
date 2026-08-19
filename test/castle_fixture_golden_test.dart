import 'dart:convert';
import 'dart:io';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/castle_fixture.dart';
import 'package:btcc/src/tflite/castle_typical_extents.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:test/test.dart';

void main() {
  final dir = Directory('test/fixtures/castles');
  late List<CastleFixture> goldens;

  setUpAll(() {
    expect(dir.existsSync(), isTrue);
    goldens = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .map((f) => CastleFixture.fromJson(
              jsonDecode(f.readAsStringSync()) as Map,
            ))
        .toList();
    expect(goldens, isNotEmpty);
  });

  test('fixture JPEGs sit beside JSON', () {
    for (final g in goldens) {
      expect(
        File('${dir.path}/${g.image}').existsSync(),
        isTrue,
        reason: '${g.image} missing next to its JSON',
      );
    }
  });

  test('every golden label maps to a tile', () {
    final helper = TileHelper();
    for (final g in goldens) {
      for (final name in [...g.labels.values, ...g.bonus, ...g.attendants]) {
        final label = TileLabels.values.firstWhere(
          (e) => e.name == name,
          orElse: () => throw StateError('${g.image}: unknown label $name'),
        );
        expect(
          () => helper.getTileIdFromLabel(label),
          returnsNormally,
          reason: '${g.image} $name',
        );
      }
    }
  });

  test('occupied includes the 2-wide throne and expectedRooms matches', () {
    for (final g in goldens) {
      final keys = g.occupied.map((c) => '${c[0]},${c[1]}').toSet();
      expect(keys.contains('0,0'), isTrue, reason: '${g.image} missing throne');
      expect(keys.contains('1,0'), isTrue, reason: '${g.image} missing placeholder');
      expect(
        g.expectedRooms,
        g.occupied.length - 2,
        reason: '${g.image}: rooms should be occupied minus throne pair',
      );
    }
  });

  test('golden labels respect detector copy limits', () {
    for (final g in goldens) {
      final counts = <String, int>{};
      for (final name in g.labels.values) {
        if (name.startsWith('TR')) continue;
        counts[name] = (counts[name] ?? 0) + 1;
      }
      for (final e in counts.entries) {
        final label = TileLabels.values.firstWhere((l) => l.name == e.key);
        expect(
          e.value,
          lessThanOrEqualTo(TfliteHelper.maxCopiesForLabel(label)),
          reason: '${g.image} ${e.key} x${e.value}',
        );
      }
    }
  });

  test('golden footprints fit typical scan extents', () {
    for (final g in goldens) {
      final xs = g.occupied.map((c) => c[0]);
      final ys = g.occupied.map((c) => c[1]);
      final spanX = xs.reduce((a, b) => a > b ? a : b) -
          xs.reduce((a, b) => a < b ? a : b) +
          1;
      final spanY = ys.reduce((a, b) => a > b ? a : b) -
          ys.reduce((a, b) => a < b ? a : b) +
          1;
      expect(
        spanX,
        lessThanOrEqualTo(CastleTypicalExtents.baseWidthWide),
        reason: '${g.image} is $spanX tiles wide',
      );
      expect(
        spanY,
        lessThanOrEqualTo(CastleTypicalExtents.verticalSpanMaxTiles),
        reason: '${g.image} is $spanY tiles tall',
      );
    }
  });
}
