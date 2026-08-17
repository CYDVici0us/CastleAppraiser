import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/analytics/analytics.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/tile_placement.dart';
import 'package:btcc/src/utils/token_tile_grid.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/builder/drag_and_drop_grid.dart';
import 'package:btcc/src/widgets/builder/expandable_grid_map_view.dart';
import 'package:btcc/src/widgets/builder/filtered_drag_and_drop_list_view.dart';
import 'package:btcc/src/widgets/builder/tile_picker_sheet.dart';
import 'package:btcc/src/widgets/button_padding.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:btcc/src/widgets/tile/scoring_blurb.dart';
import 'package:btcc/src/widgets/tile/scoring_placement_grid.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'dart:math';

class DraggedTileInfo {
  final int index;
  final Tile tile;
  DraggedTileInfo(this.index, this.tile);
}

class CastleBuilderScreen extends StatefulWidget {
  final int numPicturesTaken;
  final GridList<Tile> castleTiles;
  final String? imagePath;
  final AddCastleToGameCallback? addCastleCallback;
  final UpdateCastleCallback? updateCastleCallback;
  final Castle? existingCastle;
  final String? gameTitle;
  /// View-only: zoom map + token strip, no edit controls.
  final bool readOnly;

  CastleBuilderScreen({
    required this.castleTiles,
    this.imagePath,
    this.addCastleCallback,
    this.updateCastleCallback,
    this.existingCastle,
    this.numPicturesTaken = 0,
    this.gameTitle,
    this.readOnly = false,
  });

  @override
  _CastleBuilderScreenState createState() => new _CastleBuilderScreenState();
}

class _CastleBuilderScreenState extends State<CastleBuilderScreen>
    with SingleTickerProviderStateMixin {
  String _filterText = '';
  List<Tile> _allTiles = [];
  late GridList<Tile> _castleTiles;
  /// Bonus cards + royal attendants (not on the structural map).
  List<Tile> _tokenTiles = [];
  int? _selectedTokenIndex;
  /// Tile picked from the search row (short press).
  Tile? _selectedSearchTile;
  bool _tokenStripExpanded = false;
  DraggedTileInfo? _draggingTile;
  late Castle _castle;
  int? _selectedIndex;
  /// Index shown in the selection panel (kept during close animation).
  int? _panelIndex;
  /// Set while a grid tile is being dragged (cell already emptied).
  int? _gridDragSourceIndex;
  bool _isSaving = false;
  late final AnimationController _panelController;
  late final Animation<Offset> _panelSlide;

  static const int _minSearchLength = 3;
  static const Duration _panelAnimDuration = Duration(milliseconds: 280);

  static bool _isOccupied(Tile tile) => !tile.isEmpty();

  bool get _hasSearchTerm => _filterText.trim().isNotEmpty;
  bool get _canShowSearchResults =>
      _filterText.trim().length >= _minSearchLength;

  @override
  void initState() {
    super.initState();

    _panelController = AnimationController(
      vsync: this,
      duration: _panelAnimDuration,
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    final extracted = TokenTileGrid.extractTokenTiles(
      widget.castleTiles,
      getEmpty: () => Empty(),
    );
    _tokenTiles = extracted.tokens;
    final normalized = GridListNormalizer.normalizePerimeter(
      extracted.structural,
      isOccupied: _isOccupied,
      getEmpty: () => Empty(),
    );
    _castleTiles = normalized.grid;
    // Always start collapsed; expand only when the user taps the strip.
    _tokenStripExpanded = false;
    _refreshAvailableTiles();
    _syncCastleFromParts();
  }

  @override
  void dispose() {
    _panelController.dispose();
    super.dispose();
  }

  GridList<Tile> _mergedGrid() => TokenTileGrid.mergeTokenTilesIntoGrid(
        _castleTiles,
        _tokenTiles,
        getEmpty: () => Empty(),
      );

  void _syncCastleFromParts() {
    _castle = Castle(_mergedGrid());
    // Secrets rebind to whatever their arrow points at after DnD / place / neighbor edits.
    _castle.refreshSecretRoomDuplicates();
  }

  void _refreshAvailableTiles() {
    _allTiles = TileHelper().getListOfTilesExcludingTilesAndTrs([
      ..._castleTiles.items,
      ..._tokenTiles,
    ]);
  }

  bool _canAddAt(int index) => TilePlacement.canAddAtEmptyCell(
        _castleTiles,
        index,
        isOccupied: _isOccupied,
      );

  bool _canPlaceTileAt(
    int index,
    Tile tile, {
    bool allowAboveOutdoor = false,
    bool requireSupport = true,
  }) =>
      TilePlacement.canPlaceTile(
        _castleTiles,
        index,
        tile,
        allowAboveOutdoor: allowAboveOutdoor,
        requireSupport: requireSupport,
      );

  List<TileType>? _allowedTypesForIndex(int index) {
    final level = TilePlacement.levelRelativeToGround(_castleTiles, index);
    if (level == null) return null;
    return TilePlacement.allowedPickerTypesForLevel(level);
  }

  bool _canDropTarget(int index, Tile cell) {
    final source = _gridDragSourceIndex;
    if (source != null) {
      if (index == source) return false;
      if (TilePlacement.isOrthogonal(_castleTiles, source, index)) {
        // Need the dragged tile for type checks when crossing the throne.
        // During drag the source cell is empty; use accept with tile from DnD.
        // Drop target: rotate OK, lift-from-below push-up OK, or empty legal hole.
        if (TilePlacement.canRotateSegment(_castleTiles, source, index)) {
          return true;
        }
        if (TilePlacement.canInsertPushAcrossGround(
          _castleTiles,
          source,
          index,
          movingTile: _draggingTile?.tile,
        )) {
          return true;
        }
        return cell.isEmpty() && _canAddAt(index);
      }
      return cell.isEmpty() && _canAddAt(index);
    }
    return cell.isEmpty() && _canAddAt(index);
  }

  bool _canAcceptDraggedTile(int index, Tile tile) {
    final source = _gridDragSourceIndex;
    if (source != null) {
      if (index == source) return false;
      if (TilePlacement.isOrthogonal(_castleTiles, source, index)) {
        return TilePlacement.canOrthogonallyRelocate(
          _castleTiles,
          source,
          index,
          tile,
          canAddAt: _canAddAt,
          canPlaceTile: (i, t) => _canPlaceTileAt(i, t),
        );
      }
      return _castleTiles.items[index].isEmpty() &&
          _canAddAt(index) &&
          _canPlaceTileAt(index, tile);
    }
    // Drop from the search/list tray onto an empty legal cell.
    return _castleTiles.items[index].isEmpty() &&
        _canAddAt(index) &&
        _canPlaceTileAt(index, tile);
  }

  GridNormalizeResult<Tile> _normalize(GridList<Tile> grid) =>
      GridListNormalizer.normalizePerimeter(
        grid,
        isOccupied: _isOccupied,
        getEmpty: () => Empty(),
      );

  void _updateCastle(GridList<Tile> copy) {
    setState(() {
      _castleTiles = copy;
      _syncCastleFromParts();
      _draggingTile = null;
    });
  }

  void _clearSearchState() {
    _filterText = '';
    _selectedSearchTile = null;
  }

  void _selectGridCell(int index) {
    final opening = _panelController.value == 0;
    setState(() {
      _selectedIndex = index;
      _panelIndex = index;
      _selectedTokenIndex = null;
      _tokenStripExpanded = false;
      _clearSearchState();
    });
    if (opening) {
      _panelController.forward();
    }
  }

  void _onTapCell(int index) {
    final tile = _castleTiles.items[index];
    if (tile.tileType == TileType.Placeholder) {
      return;
    }
    _selectGridCell(index);
  }

  Future<void> _clearGridSelection() async {
    if (_panelIndex == null && _panelController.isDismissed) return;
    await _panelController.reverse();
    if (!mounted) return;
    setState(() {
      _selectedIndex = null;
      _panelIndex = null;
      _clearSearchState();
    });
  }

  void _dismissGridSelectionImmediate() {
    _panelController.value = 0;
    _selectedIndex = null;
    _panelIndex = null;
    _clearSearchState();
  }

  Future<void> _openTilePickerForSelected() async {
    final index = _selectedIndex;
    if (index == null) return;

    final chosen = await showTilePickerDialog(
      context: context,
      availableTiles: List<Tile>.from(_allTiles),
      allowedTypes: _allowedTypesForIndex(index),
    );
    if (chosen == null || !mounted) return;

    _placeTileAt(index, chosen);
  }

  void _placeTileAt(int index, Tile tile) {
    // Shared TileHelper instances may retain a stale Secret copy target.
    if (tile.isSecret()) {
      tile.duplicate = null;
    }
    final existing = _castleTiles.items[index];
    if (existing.isEmpty()) {
      if (!_canAddAt(index) || !_canPlaceTileAt(index, tile)) {
        return;
      }
    } else if (!_canPlaceTileAt(
      index,
      tile,
      allowAboveOutdoor: true,
      requireSupport: false,
    )) {
      return;
    }

    var copy = _castleTiles;
    copy.items[index] = tile;
    final normalized = _normalize(copy);

    setState(() {
      _castleTiles = normalized.grid;
      _draggingTile = null;
      _gridDragSourceIndex = null;
      _refreshAvailableTiles();
      _syncCastleFromParts();
      _selectedTokenIndex = null;
      _dismissGridSelectionImmediate();
    });
  }

  void _applySelectedSearchTile() {
    final index = _panelIndex ?? _selectedIndex;
    final tile = _selectedSearchTile;
    if (index == null || tile == null) return;
    _placeTileAt(index, tile);
  }

  void _removeSelectedTile() {
    final index = _selectedIndex;
    if (index == null) return;
    final tile = _castleTiles.items[index];
    if (!tile.isMovable()) return;

    final copy = _castleTiles;
    copy.items[index] = Empty();
    TilePlacement.compactTowardGround(copy, getEmpty: () => Empty());
    final normalized = _normalize(copy);
    final mapped = normalized.mapIndex(index);

    setState(() {
      _castleTiles = normalized.grid;
      _draggingTile = null;
      _gridDragSourceIndex = null;
      _refreshAvailableTiles();
      _syncCastleFromParts();
      _selectedIndex = mapped;
      _panelIndex = mapped;
      _selectedTokenIndex = null;
      _clearSearchState();
    });
  }

  void _applyGridDrop(int index, Tile item) {
    final source = _gridDragSourceIndex;
    var copy = _castleTiles;

    if (source != null &&
        TilePlacement.isOrthogonal(copy, source, index)) {
      final result = TilePlacement.tryOrthogonallyRelocate(
        copy,
        source,
        index,
        item,
        canAddAt: (i) => TilePlacement.canAddAtEmptyCell(
          copy,
          i,
          isOccupied: _isOccupied,
        ),
        canPlaceTile: (i, t) => TilePlacement.canPlaceTile(
          copy,
          i,
          t,
          requireSupport: true,
        ),
        getEmpty: () => Empty(),
      );
      if (result == OrthogonalMoveResult.relocated ||
          result == OrthogonalMoveResult.pushed) {
        TilePlacement.compactTowardGround(copy, getEmpty: () => Empty());
      }
      if (result != OrthogonalMoveResult.failed) {
        final normalized = _normalize(copy);
        setState(() {
          _castleTiles = normalized.grid;
          _draggingTile = null;
          _gridDragSourceIndex = null;
          _refreshAvailableTiles();
          _syncCastleFromParts();
          _selectedTokenIndex = null;
          _dismissGridSelectionImmediate();
        });
        return;
      }
    }

    if (item.tileType == TileType.ThroneRoom) {
      copy.items[index] = item;
      if (index + 1 >= copy.items.length) {
        copy.items.add(Placeholder());
      } else {
        copy.items[index + 1] = Placeholder();
      }
    } else {
      // Free drop (from tray or off-axis): must be an empty legal cell.
      if (source == null || !TilePlacement.isOrthogonal(copy, source, index)) {
        if (!copy.items[index].isEmpty() ||
            !_canAddAt(index) ||
            !_canPlaceTileAt(index, item)) {
          setState(() {
            _draggingTile = null;
            _gridDragSourceIndex = null;
          });
          return;
        }
      }
      copy.items[index] = item;
      if (source != null) {
        TilePlacement.compactTowardGround(copy, getEmpty: () => Empty());
      }
    }

    final normalized = _normalize(copy);
    setState(() {
      _castleTiles = normalized.grid;
      _draggingTile = null;
      _gridDragSourceIndex = null;
      _refreshAvailableTiles();
      _syncCastleFromParts();
      _selectedTokenIndex = null;
      _dismissGridSelectionImmediate();
    });
  }

  Future<void> _openTokenPicker({int? replaceIndex}) async {
    final replacing = (replaceIndex != null &&
            replaceIndex >= 0 &&
            replaceIndex < _tokenTiles.length)
        ? _tokenTiles[replaceIndex]
        : null;

    if (replacing == null && !TokenTileGrid.canAddAnyToken(_tokenTiles)) {
      return;
    }

    final inventory = TileHelper().getListOfTilesExcludingTilesAndTrs([
      ..._castleTiles.items,
      ..._tokenTiles.where((t) => replacing == null || t.id != replacing.id),
    ]);
    final available = TokenTileGrid.filterTokenPickerTiles(
      inventory: inventory,
      currentTokens: _tokenTiles,
      replacing: replacing,
    );
    if (available.isEmpty) return;

    final chosen = await showTilePickerDialog(
      context: context,
      availableTiles: available,
      allowedTypes: TokenTileGrid.stripPickerTypes,
    );
    if (chosen == null || !mounted) return;
    if (!TokenTileGrid.isTokenTile(chosen)) return;
    final toPlace = TokenTileGrid.resolveTokenToAdd(
      chosen,
      _tokenTiles,
      replacing: replacing,
    );

    setState(() {
      if (replaceIndex != null &&
          replaceIndex >= 0 &&
          replaceIndex < _tokenTiles.length) {
        _tokenTiles[replaceIndex] = toPlace;
      } else {
        _tokenTiles.add(toPlace);
      }
      _selectedTokenIndex = replaceIndex ?? _tokenTiles.length - 1;
      _tokenStripExpanded = true;
      _dismissGridSelectionImmediate();
      _refreshAvailableTiles();
      _syncCastleFromParts();
    });
  }

  void _removeSelectedToken() {
    final index = _selectedTokenIndex;
    if (index == null || index < 0 || index >= _tokenTiles.length) return;
    setState(() {
      _tokenTiles.removeAt(index);
      _selectedTokenIndex = null;
      if (_tokenTiles.isEmpty) {
        _tokenStripExpanded = false;
      }
      _refreshAvailableTiles();
      _syncCastleFromParts();
    });
  }

  void _showThroneRoomPicker() async {
    final chosen = await showThroneRoomPickerDialog(context);
    if (chosen == null || !mounted) return;
    var copy = _castleTiles;
    int i = copy.items.indexWhere(
        (element) => element.tileType == TileType.ThroneRoom);
    if (i < 0) return;
    copy.items.replaceRange(i, i + 1, [chosen]);
    _updateCastle(copy);
  }

  Widget _getSelectedTileDetails(
    int index,
    Tile tile, {
    bool isSearchPreview = false,
  }) {
    final theme = Theme.of(context);
    final isEmpty = tile.isEmpty();
    final isThrone = tile.isThroneRoom();
    final isActivity = tile.tileType == TileType.Activity;
    final isSecret = tile.isSecret();
    // Secrets keep printed identity in the details panel (never scoring duplicate).
    final displayType = isSecret ? tile.trueTileType : tile.tileType;
    final title = isEmpty
        ? 'Empty cell'
        : displayType == TileType.Special ||
                TokenTileGrid.isTokenType(displayType)
            ? TokenTileGrid.displayName(tile)
            : tile.name;
    final showScoring =
        !isEmpty && ScoringBlurb.hasContent(tile, includeDecoration: false);
    final showGrid = !isEmpty && ScoringPlacementMapping.shouldShow(tile);
    final showDetails = showScoring || showGrid;
    // Previewing a search hit: don't show the grid cell's placement errors.
    final invalids = isSearchPreview
        ? const <PlacementInvalidReason>[]
        : TilePlacement.invalidReasons(_castleTiles, index);
    // Compact title for wide tiles (throne / activity) so the image can be larger.
    final titleStyle = (isThrone || isActivity
            ? theme.textTheme.titleMedium
            : theme.textTheme.titleLarge)
        ?.copyWith(fontWeight: FontWeight.w700);
    final metaStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
    );
    final scoringStyle = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
      fontWeight: FontWeight.w600,
    );
    final decorationLabel = !isEmpty &&
            !isSecret &&
            tile.decorationType != DecorationType.None
        ? TokenTileGrid.humanizeCamelCase(
            tile.decorationType.toString().split('.').last,
          )
        : null;
    const sectionGap = 6.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Balance the close button so the title stays visually centered.
            const SizedBox(width: 40),
            Expanded(
              child: ScoringBlurb.titleWithCategories(
                title: title,
                style: titleStyle,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              width: 40,
              child: IconButton(
                tooltip: 'Clear selection',
                icon: const Icon(Icons.close),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                onPressed: _clearGridSelection,
              ),
            ),
          ],
        ),
        if (!isEmpty) ...[
          const SizedBox(height: 4),
          if (isThrone)
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = constraints.maxWidth /
                    (TileWidget.defaultTileWidthHeight * 2);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _selectedTileMetaRow(
                      displayType: displayType,
                      decorationLabel: decorationLabel,
                      metaStyle: metaStyle,
                      width: constraints.maxWidth,
                      alignToEdges: true,
                    ),
                    const SizedBox(height: 4),
                    TileWidget(
                      tile,
                      scale: scale,
                      showOutline: true,
                      showInvalidBadge: invalids.isNotEmpty,
                    ),
                    if (showDetails) ...[
                      const SizedBox(height: sectionGap),
                      Center(
                        child: ScoringDetailsRow(
                          tile: tile,
                          style: scoringStyle,
                          textAlign: TextAlign.start,
                          includeDecoration: false,
                          gridCellSize: 12,
                          iconScale: 0.18,
                          shrinkToFit: true,
                        ),
                      ),
                    ],
                  ],
                );
              },
            )
          else ...[
            Builder(
              builder: (context) {
                final imageScale = isActivity ? 2.0 : 1.7;
                final imageWidth =
                    TileWidget.defaultTileWidthHeight * imageScale;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: SizedBox(
                        width: imageWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _selectedTileMetaRow(
                              displayType: displayType,
                              decorationLabel: decorationLabel,
                              metaStyle: metaStyle,
                              width: imageWidth,
                              alignToEdges: false,
                            ),
                            const SizedBox(height: 4),
                            TileWidget(
                              tile,
                              scale: imageScale,
                              showOutline: true,
                              showInvalidBadge: invalids.isNotEmpty,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showDetails) ...[
                      const SizedBox(height: sectionGap),
                      // Larger score text; shrinks to fit instead of wrapping.
                      Center(
                        child: ScoringDetailsRow(
                          tile: tile,
                          style: scoringStyle,
                          textAlign: TextAlign.start,
                          includeDecoration: false,
                          gridCellSize: isActivity ? 12 : 14,
                          iconScale: 0.18,
                          shrinkToFit: true,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ] else ...[
          const SizedBox(height: 6),
          Text(
            _canAddAt(index)
                ? 'Search or tap + New Tile to place'
                : 'Cannot place a tile here',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        for (final reason in invalids) ...[
          const SizedBox(height: 4),
          Text(
            'Invalid: ${TilePlacement.describeInvalidReason(reason)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  /// Type + ornament above the tile image.
  /// Throne: flush left / right edges. Other tiles: centered on the corners.
  Widget _selectedTileMetaRow({
    required TileType displayType,
    required String? decorationLabel,
    required TextStyle? metaStyle,
    required double width,
    bool alignToEdges = false,
  }) {
    final category = Text(
      tileTypeDisplayName(displayType),
      style: metaStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (decorationLabel == null) {
      return SizedBox(
        width: width,
        child: alignToEdges
            ? Align(alignment: Alignment.centerLeft, child: category)
            : Center(child: category),
      );
    }

    final ornament = Text(decorationLabel, style: metaStyle);

    if (alignToEdges) {
      return SizedBox(
        width: width,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: category),
            const SizedBox(width: 8),
            ornament,
          ],
        ),
      );
    }

    // Center category over the left corner and ornament over the right.
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Reserve vertical space for the meta row.
          Opacity(opacity: 0, child: category),
          Positioned(
            left: 0,
            child: FractionalTranslation(
              translation: const Offset(-0.5, 0),
              child: category,
            ),
          ),
          Positioned(
            right: 0,
            child: FractionalTranslation(
              translation: const Offset(0.5, 0),
              child: ornament,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getSelectionActionBar() {
    final index = _panelIndex ?? _selectedIndex;
    if (index == null || index < 0 || index >= _castleTiles.items.length) {
      return const SizedBox.shrink();
    }

    final gridTile = _castleTiles.items[index];
    final isEmpty = gridTile.isEmpty();
    final isThrone = gridTile.tileType == TileType.ThroneRoom;
    final isMovable = gridTile.isMovable();
    final canAdd = isEmpty && _canAddAt(index);
    final searchTile = _selectedSearchTile;
    final showingSearchPreview = searchTile != null;
    final detailsTile = searchTile ?? gridTile;
    final canApplySearch = searchTile != null &&
        (isEmpty
            ? canAdd && _canPlaceTileAt(index, searchTile)
            : isMovable &&
                _canPlaceTileAt(
                  index,
                  searchTile,
                  allowAboveOutdoor: true,
                  requireSupport: false,
                ));
    // Remove only when viewing the grid tile (search cleared / no preview).
    final showRemove = isMovable && !_hasSearchTerm && !showingSearchPreview;

    Widget compactFab({
      required String heroTag,
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
    }) {
      return FloatingActionButton.extended(
        heroTag: heroTag,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
        extendedIconLabelSpacing: 6,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: onPressed,
      );
    }

    final applyFab = canApplySearch
        ? compactFab(
            heroTag: 'apply_search_tile',
            icon: isEmpty ? Icons.add : Icons.edit,
            label: isEmpty ? 'Add selected tile' : 'Update selected tile',
            onPressed: _applySelectedSearchTile,
          )
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _getSelectedTileDetails(
            index,
            detailsTile,
            isSearchPreview: showingSearchPreview,
          ),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                extendedSizeConstraints: BoxConstraints.tightFor(height: 40),
              ),
            ),
            child: applyFab != null
                ? Center(child: applyFab)
                : Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (canAdd && !_hasSearchTerm)
                              compactFab(
                                heroTag: 'add_tile',
                                icon: Icons.add,
                                label: 'New Tile',
                                onPressed: _openTilePickerForSelected,
                              ),
                            if (isMovable && !_hasSearchTerm)
                              compactFab(
                                heroTag: 'update_tile',
                                icon: Icons.edit,
                                label: 'Update',
                                onPressed: _openTilePickerForSelected,
                              ),
                            if (isThrone && !_hasSearchTerm)
                              compactFab(
                                heroTag: 'update_tr_selected',
                                icon: Icons.edit,
                                label: 'Update',
                                onPressed: _showThroneRoomPicker,
                              ),
                          ],
                        ),
                      ),
                      if (showRemove)
                        compactFab(
                          heroTag: 'remove_tile',
                          icon: Icons.delete,
                          label: 'Remove',
                          onPressed: _removeSelectedTile,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _getSelectionSearch() {
    final index = _panelIndex ?? _selectedIndex;
    if (index == null || index < 0 || index >= _castleTiles.items.length) {
      return const SizedBox.shrink();
    }

    final tile = _castleTiles.items[index];
    // Search is only for placing/replacing — hide when nothing can be placed here.
    final canSearch = tile.isMovable() || (tile.isEmpty() && _canAddAt(index));
    if (!canSearch) {
      return const SizedBox.shrink();
    }

    return FilteredDragAndDropListView<Tile>(
      key: ValueKey('tile-search-$index'),
      hintText: 'Search tiles',
      listHeight: 96,
      listItemPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      onAcceptWithDetails:
          (DragTargetDetails details, ScrollController controller) {
        if (_draggingTile != null) {
          log('OnAcceptWithDetails from listview drag: ${details.offset}');
          var copy = _allTiles;
          copy.insert(_draggingTile!.index, _draggingTile!.tile);
          setState(() {
            _draggingTile = null;
            _allTiles = copy;
          });
        } else {
          log('OnAcceptWithDetails from grid: ${details.offset}');

          int scrollOffsetIndex =
              controller.offset ~/ TileWidget.defaultTileWidthHeight;
          int dragOffsetIndex =
              details.offset.dx ~/ TileWidget.defaultTileWidthHeight + 1;
          int roughIndex =
              min(_allTiles.length, scrollOffsetIndex + dragOffsetIndex);

          var copy = _allTiles;
          copy.insert(roughIndex, details.data);
          final normalized = _normalize(_castleTiles);
          setState(() {
            _allTiles = copy;
            _castleTiles = normalized.grid;
            _syncCastleFromParts();
            _gridDragSourceIndex = null;
          });
        }
      },
      onClearPressed: () {
        setState(() {
          _clearSearchState();
        });
      },
      onTextChanged: (String value) {
        setState(() {
          _filterText = value;
          if (value.trim().length < _minSearchLength) {
            _selectedSearchTile = null;
          } else if (_selectedSearchTile != null &&
              !_getFilteredTiles()
                  .any((t) => t.id == _selectedSearchTile!.id)) {
            _selectedSearchTile = null;
          }
        });
      },
      children: _getFilteredListViewChildren(),
    );
  }

  Widget _getSelectionPanel() {
    final theme = Theme.of(context);
    final index = _panelIndex;
    if (index == null || index < 0 || index >= _castleTiles.items.length) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.5),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _getSelectionActionBar(),
                  _getSelectionSearch(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getAnimatedSelectionPanel() {
    return AnimatedBuilder(
      animation: _panelController,
      builder: (context, child) {
        if (_panelController.value == 0 && _panelIndex == null) {
          return const SizedBox.shrink();
        }
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _panelController.value,
            child: SlideTransition(
              position: _panelSlide,
              child: IgnorePointer(
                ignoring: _panelController.status == AnimationStatus.reverse,
                child: child,
              ),
            ),
          ),
        );
      },
      child: _getSelectionPanel(),
    );
  }

  Widget _getTokenStrip() {
    final theme = Theme.of(context);
    final selected = _selectedTokenIndex;
    final count = _tokenTiles.length;
    final readOnly = widget.readOnly;

    if (readOnly && count == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _tokenStripExpanded = !_tokenStripExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.style_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bonus & Royal attendants',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      _tokenStripExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_tokenStripExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: TileWidget.defaultTileWidthHeight * 0.65,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tokenTiles.length +
                            (!readOnly &&
                                    TokenTileGrid.canAddAnyToken(_tokenTiles)
                                ? 1
                                : 0),
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index == _tokenTiles.length) {
                            return InkWell(
                              onTap: () => _openTokenPicker(),
                              child: Container(
                                width: TileWidget.defaultTileWidthHeight * 0.65,
                                height: TileWidget.defaultTileWidthHeight * 0.65,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                  color: theme.colorScheme.surface.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }

                          final tile = _tokenTiles[index];
                          final isSelected = !readOnly && selected == index;
                          return InkWell(
                            onTap: readOnly
                                ? null
                                : () {
                                    setState(() {
                                      _selectedTokenIndex = index;
                                      _dismissGridSelectionImmediate();
                                    });
                                  },
                            child: Container(
                              foregroundDecoration: isSelected
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        width: 2,
                                        color: Colors.lightBlueAccent,
                                      ),
                                    )
                                  : null,
                              child: TileWidget(
                                tile,
                                scale: 0.65,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (!readOnly &&
                        selected != null &&
                        selected >= 0 &&
                        selected < _tokenTiles.length) ...[
                      const SizedBox(height: 6),
                      _getSelectedTokenDetails(_tokenTiles[selected], selected),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _getSelectedTokenDetails(Tile tile, int selected) {
    final theme = Theme.of(context);
    final title = TokenTileGrid.displayName(tile);
    final typeLabel = tileTypeDisplayName(tile.tileType);
    final showScoring = ScoringBlurb.hasContent(tile);
    final imageScale =
        (MediaQuery.of(context).size.width * 0.42) /
            TileWidget.defaultTileWidthHeight;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final scoringStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Spacer(),
            IconButton(
              tooltip: 'Clear selection',
              icon: const Icon(Icons.close),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _selectedTokenIndex = null;
                });
              },
            ),
          ],
        ),
        Center(
          child: TileWidget(
            tile,
            scale: imageScale.clamp(1.2, 2.0),
          ),
        ),
        const SizedBox(height: 12),
        ScoringBlurb.titleWithCategories(
          title: title,
          style: titleStyle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          typeLabel,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        if (showScoring) ...[
          const SizedBox(height: 6),
          ScoringBlurb(
            tile: tile,
            style: scoringStyle,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            TextButton(
              onPressed: () => _openTokenPicker(replaceIndex: selected),
              child: const Text('Update'),
            ),
            const Spacer(),
            TextButton(
              onPressed: _removeSelectedToken,
              child: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _getBody() => ExpandableGridMapView<Tile>(
        gridList: _castleTiles,
        getEmpty: () => Empty(),
        canDragItem: (item) => !widget.readOnly && item.isMovable(),
        isOccupied: _isOccupied,
        canDropOnItem: _canDropTarget,
        canAcceptDraggedItem: _canAcceptDraggedTile,
        builder: (context, index, item) => TileWidget(
          item,
          showOutline: true,
          showInvalidBadge: !widget.readOnly &&
              TilePlacement.hasInvalidPlacement(_castleTiles, index),
        ),
        feedback: (context, index, item) => TileWidget(
          item,
          showInvalidBadge:
              TilePlacement.hasInvalidPlacement(_castleTiles, index),
        ),
        wrapperOnDropHover: (item, built) => Container(
          child: built,
          foregroundDecoration: BoxDecoration(
            border: Border.all(
              width: 15,
              color: Colors.lightBlueAccent,
            ),
          ),
        ),
        selectedIndex: widget.readOnly ? null : _selectedIndex,
        initialCenterIndex: _castleTiles.items.indexWhere(
          (t) => t.isThroneRoom(),
        ),
        onTapItem: widget.readOnly ? null : _onTapCell,
        onDropOnItem: _applyGridDrop,
        onDragItem: (int index) {
          var copy = _castleTiles;
          var item = copy.items[index];
          // Drop any stale Secret copy target; rebinding happens on drop/sync.
          if (item.isSecret()) {
            item.duplicate = null;
          }
          if (item.tileType == TileType.ThroneRoom) {
            copy.items[index] = Empty();
            copy.items[index + 1] = Empty();
          } else {
            copy.items[index] = Empty();
          }

          setState(() {
            _castleTiles = copy;
            _syncCastleFromParts();
            _draggingTile = DraggedTileInfo(index, item);
            _gridDragSourceIndex = index;
            _selectedTokenIndex = null;
            _dismissGridSelectionImmediate();
          });
        },
        onExpandCollapse: (result) {
          _updateCastle(result);
          setState(() {
            _refreshAvailableTiles();
          });
        },
        onDragCancelled: (int index, Tile item) {
          var copy = _castleTiles;
          if (item.tileType == TileType.ThroneRoom) {
            copy.items[index] = item;
            if (index + 1 >= copy.items.length) {
              copy.items.add(Placeholder());
            } else {
              copy.items[index + 1] = Placeholder();
            }
          } else {
            copy.items[index] = item;
          }

          final normalized = _normalize(copy);
          setState(() {
            _castleTiles = normalized.grid;
            _syncCastleFromParts();
            _draggingTile = null;
            _gridDragSourceIndex = null;
          });
        },
      );

  List<Tile> _getFilteredTiles() {
    if (!_canShowSearchResults) return const [];
    final text = _filterText.trim().toLowerCase();
    final selected = _panelIndex ?? _selectedIndex;
    final allowed =
        selected != null ? _allowedTypesForIndex(selected) : null;
    return _allTiles.where((element) {
      if (!element.name.toLowerCase().contains(text)) return false;
      if (allowed != null && !allowed.contains(element.trueTileType)) {
        return false;
      }
      if (selected != null) {
        final existing = _castleTiles.items[selected];
        final ok = existing.isEmpty()
            ? _canPlaceTileAt(selected, element)
            : _canPlaceTileAt(
                selected,
                element,
                allowAboveOutdoor: true,
                requireSupport: false,
              );
        if (!ok) return false;
      }
      return true;
    }).toList();
  }

  List<Widget> _getFilteredListViewChildren() {
    final filtered = _getFilteredTiles();
    final selectedId = _selectedSearchTile?.id;
    // Fit inside listHeight with vertical padding; keep every thumb square.
    const thumbSize = 88.0;
    return filtered
        .map((tile) {
          final isSelected = selectedId == tile.id;
          final thumb = _searchTileThumb(tile, size: thumbSize);
          return LongPressDraggable<Tile>(
            delay: DragAndDropGrid.dragDelay,
            data: tile,
            feedback: Material(
              color: Colors.transparent,
              child: thumb,
            ),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: thumb,
            ),
            onDragStarted: () {
              log('alltiles length ${_allTiles.length}');
              var copy = _allTiles;
              int index = copy.indexWhere((element) => element.id == tile.id);
              log('OnDragStarted from list view: $index');
              copy.removeAt(index);
              log('copy length ${copy.length}');
              setState(() {
                _allTiles = copy;
                _draggingTile = DraggedTileInfo(index, tile);
                _selectedSearchTile = null;
              });
            },
            onDraggableCanceled: (velocity, offset) {
              log('OnDragCancelled from list view: ${_draggingTile!.index}');
              var copy = _allTiles;
              copy.insert(_draggingTile!.index, _draggingTile!.tile);
              setState(() {
                _draggingTile = null;
                _allTiles = copy;
              });
            },
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSearchTile =
                      isSelected ? null : tile;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                foregroundDecoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(
                          width: 3,
                          color: Colors.lightBlueAccent,
                        ),
                      )
                    : null,
                child: thumb,
              ),
            ),
          );
        })
        .toList();
  }

  /// Uniform square search thumb — clips/fits any tile aspect into [size]².
  Widget _searchTileThumb(Tile tile, {required double size}) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: TileWidget(tile),
        ),
      ),
    );
  }

  Future<void> _persistCastle() async {
    var castle = Castle(_mergedGrid());
    if (widget.updateCastleCallback != null &&
        widget.existingCastle != null) {
      castle.hiveCastle = widget.existingCastle!.hiveCastle;
      castle.title = widget.existingCastle!.title;
      await widget.updateCastleCallback!(castle);
      await Analytics.logCastleSavedFromCastleBuilder(widget.numPicturesTaken);
      return;
    }

    if (widget.addCastleCallback != null) {
      await widget.addCastleCallback!(
          castle, widget.imagePath ?? '', widget.numPicturesTaken);
      await Analytics.logCastleSavedFromCastleBuilder(widget.numPicturesTaken);
    }
  }

  /// Explicit commit — only used by Save and close.
  Future<void> _saveAndPop() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await _persistCastle();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      _isSaving = false;
    }
  }

  /// Back arrow, swipe/system back, Cancel, and breadcrumb leave without saving.
  void _discardAndPop() {
    if (_isSaving) return;
    Navigator.of(context).pop();
  }

  void _discardToHome() {
    if (_isSaving) return;
    NavigationHelper.popToHome(context);
  }

  Widget _getCancelButton() => FloatingActionButton.extended(
        heroTag: 'cancel',
        icon: Icon(Icons.cancel_outlined),
        label: Text('Cancel changes'),
        onPressed: _isSaving ? null : _discardAndPop,
      );

  Widget _getSaveAndCloseButton() => FloatingActionButton.extended(
        heroTag: 'save_close',
        icon: Icon(Icons.check),
        label: Text('Save and close'),
        onPressed: _isSaving ? null : _saveAndPop,
      );

  Widget _getBottomButtonRow() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _getSaveAndCloseButton(),
            Flexible(
              child: Container(),
            ),
            _getCancelButton(),
          ],
        ),
      );

  Widget _getBottomSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _getAnimatedSelectionPanel(),
        ButtonPadding(),
        _getBottomButtonRow(),
        ButtonPadding(),
      ],
    );
  }

  void _showEditHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editing a castle'),
        content: const SingleChildScrollView(
          child: Text(
            'Tap an empty or filled slot on the grid to select it and open '
            'its details.\n\n'
            'Long-press a tile on the grid to drag and drop it onto another '
            'slot.\n\n'
            'Zoom with the + and - buttons on the map (or pinch) to get a '
            'closer look while editing.\n\n'
            'With a slot selected, use New Tile (or Update) to browse by '
            'category, or type in Search tiles to find a room by name. Tap a '
            'search result to preview it, then Add or Update selected tile '
            'to place it.\n\n'
            'Placement rules:\n'
            '• Rooms must connect to the castle (or fill an interior hole).\n'
            '• Upper floors need a room directly below; downstairs rooms '
            'need a room directly above.\n'
            '• Downstairs rooms go below the throne row; Activity and most '
            'other rooms go on or above ground.\n'
            '• Nothing can sit above Outdoor, Tower, or Fountain.\n'
            '• Invalid placements show a warning on the tile.\n\n'
            'Bonus cards and Royal attendants are not placed on the grid. '
            'Open the Bonus & Royal attendants strip at the top, tap +, and '
            'pick from the available tokens. Tap a token in the strip to '
            'view or replace it.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: Theme.of(ctx).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.readOnly;
    final editing = widget.updateCastleCallback != null;
    final gameName = widget.gameTitle ?? 'Game';
    final castleName =
        widget.existingCastle?.title ?? (editing ? 'Castle' : 'New Castle');
    final segments = <String>[
      gameName,
      castleName,
      if (readOnly) 'View' else if (editing) 'Edit' else 'Build',
    ];

    return Scaffold(
      appBar: AppBar(
        // Default back / swipe discards; only Save and close persists.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: readOnly ? 'Back' : 'Discard changes',
          onPressed: _isSaving ? null : _discardAndPop,
        ),
        title: FlowBreadcrumb(
          showHome: true,
          onHomeTap: _discardToHome,
          segments: segments,
          onSegmentTap: (index) {
            // Game or castle name → leave without saving (same as back).
            if (index == 0 || index == 1) {
              _discardAndPop();
            }
          },
        ),
        actions: [
          if (!readOnly)
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help',
              onPressed: _showEditHelpDialog,
            ),
        ],
      ),
      body: BackgroundContainer(
        child: Column(
          children: [
            _getTokenStrip(),
            Expanded(
              child: _getBody(),
            ),
            if (!readOnly)
              Align(
                alignment: FractionalOffset.bottomCenter,
                child: _getBottomSheet(),
              ),
          ],
        ),
      ),
    );
  }
}
