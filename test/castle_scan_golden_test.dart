import 'dart:convert';
import 'dart:io';

import 'package:btcc/src/tflite/castle_fixture.dart';
import 'package:btcc/src/tflite/castle_scan_run.dart';
import 'package:test/test.dart';

/// Scan JSON is a detector pass. It must point at a real golden and the same
/// throne type — a Castle 3 export labeled as Castle 4 slipped through once.
void main() {
  final scansDir = Directory('test/fixtures/scans');
  final goldensDir = Directory('test/fixtures/castles');

  test('scan runs reference existing goldens with matching thrones', () {
    expect(scansDir.existsSync(), isTrue);
    expect(goldensDir.existsSync(), isTrue);

    final scanFiles = scansDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(scanFiles, isNotEmpty);

    for (final file in scanFiles) {
      final raw = jsonDecode(file.readAsStringSync()) as Map;
      final run = CastleScanRun.fromJson(raw);
      expect(
        CastleScanRun.looksLikeFixtureGolden(run.golden),
        isTrue,
        reason: '${file.uri.pathSegments.last} golden "${run.golden}"',
      );

      final goldenFile = File('${goldensDir.path}/${run.golden}');
      expect(
        goldenFile.existsSync(),
        isTrue,
        reason: '${file.uri.pathSegments.last} points at missing ${run.golden}',
      );

      final golden = CastleFixture.fromJson(
        jsonDecode(goldenFile.readAsStringSync()) as Map,
      );
      expect(
        run.labels['0,0'],
        golden.labels['0,0'],
        reason: '${file.uri.pathSegments.last} throne vs ${run.golden}',
      );

      final diff = run.diffGolden(golden);
      // Frozen detector output — print the gap so new scans are easy to judge.
      // ignore: avoid_print
      print('${file.uri.pathSegments.last}\n$diff');
    }
  });
}
