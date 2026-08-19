import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Repo fixture photos (`test/fixtures/castles/`) and the Debug game.
///
/// These JPEGs are **not** Flutter assets — they must not ship in release
/// APKs. The debug picker reads them from disk when the app is run from the
/// repo (desktop / `flutter run` with cwd at the project). On a phone, use
/// Take or pick a photo instead.
class DebugCastleAssets {
  DebugCastleAssets._();

  static const String gameTitle = 'Debug';
  static const String relativeDirectory = 'test/fixtures/castles';

  static bool isDebugGameTitle(String? title) =>
      (title ?? '').trim() == gameTitle;

  /// Directory that contains fixture JPEGs/JSON, or null if this process
  /// cannot see the git checkout (typical on a device).
  static Future<Directory?> fixturesDirectory() async {
    for (final candidate in _searchRoots()) {
      final dir = Directory('$candidate${Platform.pathSeparator}$relativeDirectory'
          .replaceAll('/', Platform.pathSeparator));
      if (await dir.exists()) return dir;
    }
    return null;
  }

  static Iterable<String> _searchRoots() sync* {
    var current = Directory.current;
    for (var i = 0; i < 6; i++) {
      yield current.path;
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
  }

  static Future<List<String>> listImageFiles() async {
    final dir = await fixturesDirectory();
    if (dir == null) return const [];
    final files = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .where((path) {
          final lower = path.toLowerCase();
          return lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.png');
        })
        .toList()
      ..sort();
    return files;
  }

  static String basename(String assetPath) =>
      assetPath.replaceAll('\\', '/').split('/').last;

  static String stem(String filename) {
    final name = basename(filename);
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return name;
    return name.substring(0, dot);
  }

  /// Copy a fixture photo into [destDir] (or a temp dir) so Scan/Grid can
  /// use an app-writable path. Returns the written file path.
  static Future<String> copyFileToDirectory(
    String sourcePath, {
    String? destDir,
  }) async {
    final dirPath = (destDir != null && destDir.isNotEmpty)
        ? destDir
        : (await getTemporaryDirectory()).path;
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final dest = File('$dirPath/${basename(sourcePath)}');
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }
}
