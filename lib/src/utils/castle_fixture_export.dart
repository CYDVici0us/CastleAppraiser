import 'dart:io';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/castle_fixture.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Share fixture JSON plus the castle photo (to drop into test/fixtures/castles).
class CastleFixtureExport {
  CastleFixtureExport._();

  static Future<void> share(Castle castle) async {
    final hive = castle.hiveCastle;
    final imageFileName =
        '${_fileStem(castle.title)}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final fixture = CastleFixture.fromCastle(
      castle,
      imageFileName: imageFileName,
      fromAsset: false,
    );

    final directory = await getTemporaryDirectory();
    final jsonFile = File('${directory.path}/${fixture.jsonFileName}');
    await jsonFile.writeAsString(fixture.toPrettyJson(), flush: true);

    final files = <XFile>[XFile(jsonFile.path, mimeType: 'application/json')];
    final sourcePath = hive?.imagePath;
    if (sourcePath != null && sourcePath.isNotEmpty) {
      final source = File(sourcePath);
      if (await source.exists()) {
        final imageDest = File('${directory.path}/${fixture.image}');
        await source.copy(imageDest.path);
        files.add(XFile(imageDest.path, mimeType: 'image/jpeg'));
      }
    }

    log('Exporting fixture ${fixture.image} rooms=${fixture.expectedRooms} '
        'bonus=${fixture.bonus.length} attendants=${fixture.attendants.length}');

    await SharePlus.instance.share(
      ShareParams(
        files: files,
        text: 'Debug castle fixture + photo ${fixture.image}',
      ),
    );
  }

  static String _fileStem(String title) {
    final cleaned = title.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
    if (cleaned.isEmpty) return 'castle';
    return cleaned;
  }
}
