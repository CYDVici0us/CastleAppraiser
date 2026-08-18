import 'dart:io';

import 'package:btcc/src/analytics/analytics.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/state/camera_store.dart';
import 'package:btcc/src/tflite/cell_guess_info.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/orientation_helper.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/builder/tile_picker_sheet.dart';
import 'package:btcc/src/widgets/button_padding.dart';
import 'package:btcc/src/widgets/castle/castle_tiles_grid.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:btcc/src/widgets/interactive_modal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CastleConfirmScreen extends StatefulWidget {
  final int numPicturesTaken;
  final GridList<Tile> castleTiles;
  final String? imagePath;
  final AddCastleToGameCallback addCastleCallback;
  final String? gameTitle;
  final int? expectedRoomTileCount;
  final Map<int, CellGuessInfo>? cellGuesses;
  final bool offerGridMode;

  const CastleConfirmScreen({
    super.key,
    required this.castleTiles,
    this.imagePath,
    required this.addCastleCallback,
    this.numPicturesTaken = 0,
    this.gameTitle,
    this.expectedRoomTileCount,
    this.cellGuesses,
    this.offerGridMode = false,
  });

  @override
  State<CastleConfirmScreen> createState() => _CastleConfirmScreenState();
}

class _CastleConfirmScreenState extends State<CastleConfirmScreen> {
  late GridList<Tile> _tiles;
  late Map<int, CellGuessInfo> _guesses;
  int? _highlightIndex;

  @override
  void initState() {
    super.initState();
    _tiles = GridList(
      widget.castleTiles.width,
      List<Tile>.from(widget.castleTiles.items),
    );
    _guesses = Map<int, CellGuessInfo>.from(widget.cellGuesses ?? {});
  }

  int get _uncertainCount =>
      _guesses.values.where((g) => g.needsReview).length;

  int? _nextUncertainIndex() {
    for (var i = 0; i < _tiles.items.length; i++) {
      final info = _guesses[i];
      if (info != null && info.needsReview) return i;
    }
    return null;
  }

  Future<void> _onCellTap(int index) async {
    final tile = _tiles.items[index];
    if (tile.isPlaceholder()) return;

    final info = _guesses[index];
    if (info != null &&
        info.alternatives.isNotEmpty &&
        info.needsReview) {
      final picked = await _showAlternatives(info);
      if (picked != null && mounted) {
        setState(() {
          _tiles.items[index] = picked;
          _guesses.remove(index);
          _highlightIndex = null;
        });
        return;
      }
    }

    final chosen = await showTilePickerDialog(
      context: context,
      availableTiles: TileHelper().listOfAllTiles,
    );
    if (chosen != null && mounted) {
      setState(() {
        _tiles.items[index] = chosen;
        _guesses.remove(index);
        _highlightIndex = null;
      });
    }
  }

  Future<Tile?> _showAlternatives(CellGuessInfo info) async {
    final helper = TileHelper();
    final options = info.alternatives
        .map((l) => helper.getTileByLabel(l))
        .toList();
    if (options.isEmpty) return null;

    return showDialog<Tile>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pick the closest match'),
        children: [
          for (final t in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: Text(t.name),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('More tiles…'),
          ),
        ],
      ),
    );
  }

  void _nextUncertain() {
    final next = _nextUncertainIndex();
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No uncertain tiles left')),
      );
      return;
    }
    setState(() => _highlightIndex = next);
  }

  void _switchToGrid() {
    if (widget.imagePath == null) return;
    NavigationHelper.goToTileSelectionFlowScreen(
      context,
      widget.imagePath!,
      replace: true,
      addCastleCallback: widget.addCastleCallback,
      numPicturesTaken: widget.numPicturesTaken,
      gameTitle: widget.gameTitle,
      expectedRoomTileCount: widget.expectedRoomTileCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final placedRooms = TfliteHelper.countPlacedRoomTiles(_tiles);
    final expected = widget.expectedRoomTileCount;
    final underExpected =
        TfliteHelper.isUnderExpectedRoomCount(placedRooms, expected);
    final uncertain = _uncertainCount;

    return Scaffold(
      appBar: AppBar(
        title: FlowBreadcrumb(
          showHome: true,
          onHomeTap: () {
            OrientationHelper.lockPortrait();
            NavigationHelper.popToHome(context);
          },
          segments: [widget.gameTitle ?? 'Game', 'Confirm'],
          onSegmentTap: (index) {
            if (index == 0) {
              OrientationHelper.lockPortrait();
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (uncertain > 0)
            TextButton.icon(
              onPressed: _nextUncertain,
              icon: const Icon(Icons.navigate_next),
              label: Text('Next ($uncertain)'),
            ),
        ],
      ),
      body: BackgroundContainer(
        child: Column(
          children: [
            if (uncertain > 0)
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$uncertain tile${uncertain == 1 ? '' : 's'} need a '
                          'look — tap to fix or use Next.',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (underExpected)
              Material(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Found $placedRooms of $expected expected room tiles. '
                          'Check wings and basement, or edit before saving.',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.offerGridMode)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.grid_on,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  title: Text(
                    'Scan found far fewer tiles than expected.',
                    style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  subtitle: Text(
                    'Try Grid mode to mark the castle outline.',
                    style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: _switchToGrid,
                    child: const Text('Switch to Grid'),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  InteractiveModalWidget(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height / 4.5,
                        maxWidth: MediaQuery.of(context).size.width,
                      ),
                      child: widget.imagePath == null
                          ? const SizedBox.shrink()
                          : Image.file(
                              File(widget.imagePath!),
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: InteractiveModalWidget(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: CastleTilesGrid(
                            _tiles,
                            scaleWithScreen: false,
                            cellGuesses: _guesses,
                            highlightIndex: _highlightIndex,
                            onCellTap: _onCellTap,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'Is this correct?',
              style: TextStyle(fontSize: 24),
            ),
            ButtonPadding(),
            Row(
              children: [
                Consumer<CameraStore>(
                  builder: (_, cameraStore, __) =>
                      FloatingActionButton.extended(
                    heroTag: 'picture',
                    backgroundColor: Colors.redAccent,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('No, Redo'),
                    onPressed: () => NavigationHelper.goToCameraExperience(
                      context,
                      addCastleCallback: widget.addCastleCallback,
                      numPicturesTaken: widget.numPicturesTaken,
                      replace: true,
                      cameraTech: cameraStore.cameraTech,
                      gameTitle: widget.gameTitle,
                    ),
                  ),
                ),
                Flexible(child: Container()),
                FloatingActionButton.extended(
                  heroTag: 'edit',
                  backgroundColor: Colors.redAccent,
                  icon: const Icon(Icons.edit),
                  label: const Text('No, Edit'),
                  onPressed: () {
                    NavigationHelper.goToCastleBuilderScreen(
                      context,
                      castleTiles: _tiles,
                      imagePath: widget.imagePath,
                      replace: true,
                      addCastleCallback: widget.addCastleCallback,
                      numPicturesTaken: widget.numPicturesTaken,
                      gameTitle: widget.gameTitle,
                    );
                  },
                ),
                Flexible(child: Container()),
                FloatingActionButton.extended(
                  heroTag: 'castle',
                  backgroundColor: Colors.green,
                  icon: const Icon(Icons.check),
                  label: const Text('Yes'),
                  onPressed: () async {
                    final castle = Castle(_tiles);
                    await widget.addCastleCallback(
                      castle,
                      widget.imagePath ?? '',
                      widget.numPicturesTaken,
                    );
                    Analytics.logCastleSavedFromPicture(
                      widget.numPicturesTaken,
                    );
                    OrientationHelper.lockPortrait();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
            ButtonPadding(),
          ],
        ),
      ),
    );
  }
}
