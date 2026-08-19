import 'dart:io';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/castle_fixture.dart';
import 'package:btcc/src/tflite/castle_scan_run.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Share fixture JSON plus the castle photo (to drop into test/fixtures/castles).
class CastleFixtureExport {
  CastleFixtureExport._();

  /// Basename for [CastleScanRun.golden] when the fixture does not exist yet.
  static String suggestedScanGolden(Castle castle) {
    final linked = castle.hiveCastle?.debugGoldenJson?.trim();
    if (linked != null && linked.isNotEmpty) {
      return CastleScanRun.normalizeGoldenName(linked);
    }
    return CastleScanRun.placeholderGolden;
  }

  /// Export occupancy + photo golden. Returns the JSON basename (e.g.
  /// `Castle_5_1787123456789.json`) and stores it on the castle for scan export.
  static Future<String> share(Castle castle) async {
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

    await _rememberGolden(castle, fixture.jsonFileName);
    return fixture.jsonFileName;
  }

  /// Ask which golden this pass belongs to, then share scan JSON only.
  static Future<void> promptAndShareScan(
    BuildContext context,
    Castle castle,
  ) async {
    final golden = await showDialog<String>(
      context: context,
      builder: (ctx) => _GoldenNameDialog(
        initial: suggestedScanGolden(castle),
      ),
    );
    if (golden == null || golden.isEmpty) return;
    if (!context.mounted) return;
    await shareScan(castle, golden: golden);
  }

  static Future<void> shareScan(
    Castle castle, {
    required String golden,
  }) async {
    final normalized = CastleScanRun.normalizeGoldenName(golden);
    if (normalized.isEmpty) {
      throw ArgumentError('Golden JSON filename is required');
    }

    final run = CastleScanRun.fromCastle(castle, golden: normalized);
    final directory = await getTemporaryDirectory();
    final jsonFile = File('${directory.path}/${run.jsonFileName}');
    await jsonFile.writeAsString(run.toPrettyJson(), flush: true);

    log('Exporting scan ${run.jsonFileName} golden=${run.golden} '
        'scanCells=${run.scan.length} rooms=${run.expectedRooms}');

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(jsonFile.path, mimeType: 'application/json')],
        text: 'Debug scan for golden ${run.golden} — drop in test/fixtures/scans',
      ),
    );

    await _rememberGolden(castle, normalized);
  }

  static Future<void> _rememberGolden(Castle castle, String goldenJson) async {
    if (!kDebugMode) return;
    final hive = castle.hiveCastle;
    if (hive == null || !hive.isInBox) return;
    hive.debugGoldenJson = CastleScanRun.normalizeGoldenName(goldenJson);
    await hive.save();
  }

  static String _fileStem(String title) {
    final cleaned = title.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
    if (cleaned.isEmpty) return 'castle';
    return cleaned;
  }
}

class _GoldenNameDialog extends StatefulWidget {
  final String initial;

  const _GoldenNameDialog({required this.initial});

  @override
  State<_GoldenNameDialog> createState() => _GoldenNameDialogState();
}

class _GoldenNameDialogState extends State<_GoldenNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = CastleScanRun.normalizeGoldenName(_controller.text);
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export scan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'One detector pass — references a golden file, not ground truth.\n\n'
            'Typical order:\n'
            '1. Export scan with TBD.json (or any placeholder)\n'
            '2. Fix the castle, then Export fixture (JSON + photo)\n'
            '3. Export scan again — the golden name is prefilled\n\n'
            'To fix an earlier scan file, edit its "golden" field or re-export.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Golden JSON',
              hintText: CastleScanRun.placeholderGolden,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Export'),
        ),
      ],
    );
  }
}
