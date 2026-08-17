/// How the user adds a castle from a photo after capture.
enum AddCastleMode {
  /// Automatic ML detection (frame / full photo, existing pipeline).
  tileScan,

  /// Manual grid: align throne, mark cells, classify each tile.
  tileSelection,
}

extension AddCastleModeLabel on AddCastleMode {
  String get label => switch (this) {
        AddCastleMode.tileScan => 'Full image scan',
        AddCastleMode.tileSelection => 'Grid',
      };

  String get description => switch (this) {
        AddCastleMode.tileScan =>
          'Automatic detection — optional crop, then scan the photo',
        AddCastleMode.tileSelection =>
          'Align throne & grid, tap each tile, classify individually',
      };
}
