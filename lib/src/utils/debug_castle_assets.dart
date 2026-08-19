/// Debug-only fixture lab (game title) and helpers for exported filenames.
class DebugCastleAssets {
  DebugCastleAssets._();

  static const String gameTitle = 'Debug';

  static bool isDebugGameTitle(String? title) =>
      (title ?? '').trim() == gameTitle;

  static String basename(String path) =>
      path.replaceAll('\\', '/').split('/').last;
}
