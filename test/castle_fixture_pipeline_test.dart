import 'dart:convert';
import 'dart:io';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/state/tf_store.dart';
import 'package:btcc/src/tflite/castle_fixture.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/tflite_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs Scan on repo fixture photos and diffs occupancy/labels vs goldens.
/// Requires the TFLite native library (Android / a host with the C API DLL).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dir = Directory('test/fixtures/castles');

  test('Scan pipeline vs fixture goldens', () async {
    expect(dir.existsSync(), isTrue, reason: 'test/fixtures/castles missing');

    final store = TfStore();
    final loaded = await store.init(TfliteModel.scoring, true);
    if (!loaded) {
      markTestSkipped(
        'TFLite native library not available on this host; run on a device',
      );
      return;
    }

    final jsonFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(jsonFiles, isNotEmpty);

    final reports = <String>[];
    var anyFail = false;

    for (final jsonFile in jsonFiles) {
      final raw = jsonDecode(jsonFile.readAsStringSync()) as Map;
      if (CastleFixture.isScanDocument(raw)) continue;
      final golden = CastleFixture.fromJson(raw);
      final imageFile = File('${dir.path}/${golden.image}');
      if (!imageFile.existsSync()) {
        reports.add('${golden.image}: missing JPEG beside JSON');
        anyFail = true;
        continue;
      }

      final guesses = await store.runOnImage(
        imageFile.path,
        expectedRoomTileCount: golden.expectedRooms,
      );
      final built = TfliteHelper.convertGuessesToCastleWithInfo(guesses);
      final actual = CastleFixture.fromCastle(
        Castle(built.grid),
        imageFileName: golden.image,
        fromAsset: false,
      );
      final diff = golden.diff(actual);
      final line = '${golden.image}\n$diff\n'
          'detections=${guesses.length} '
          'rooms=${TfliteHelper.countRoomDetections(guesses)}';
      // ignore: avoid_print
      print(line);
      reports.add(line);
      if (!diff.isPerfect) anyFail = true;
    }

    expect(
      anyFail,
      isFalse,
      reason: 'Fixture mismatches:\n${reports.join('\n---\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 20)), tags: ['fixture-pipeline']);
}
