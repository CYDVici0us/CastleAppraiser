import 'dart:io';

import 'package:btcc/src/analytics/analytics.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/state/camera_store.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/orientation_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/button_padding.dart';
import 'package:btcc/src/widgets/castle/castle_tiles_grid.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:btcc/src/widgets/interactive_modal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CastleConfirmScreen extends StatelessWidget {

  final int numPicturesTaken;
  final GridList<Tile> castleTiles;
  final String? imagePath;
  final AddCastleToGameCallback addCastleCallback;
  final String? gameTitle;
  final int? expectedRoomTileCount;

  CastleConfirmScreen({
    required this.castleTiles,
    this.imagePath,
    required this.addCastleCallback,
    this.numPicturesTaken=0,
    this.gameTitle,
    this.expectedRoomTileCount,
  });

  @override
  Widget build(BuildContext context) {
    final placedRooms = TfliteHelper.countPlacedRoomTiles(castleTiles);
    final expected = expectedRoomTileCount;
    final underExpected =
        TfliteHelper.isUnderExpectedRoomCount(placedRooms, expected);

    return Scaffold(
    appBar: AppBar(
      title: FlowBreadcrumb(
        showHome: true,
        onHomeTap: () {
          OrientationHelper.lockPortrait();
          NavigationHelper.popToHome(context);
        },
        segments: [gameTitle ?? 'Game', 'Confirm'],
        onSegmentTap: (index) {
          if (index == 0) {
            OrientationHelper.lockPortrait();
            Navigator.of(context).pop();
          }
        },
      ),
    ),
    body: BackgroundContainer(
      child: Column(
        children: [
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
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Found $placedRooms of $expected expected room tiles. '
                        'Check wings and basement, or edit before saving.',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
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
                    child: imagePath == null
                        ? const SizedBox.shrink()
                        : Image.file(
                            File(imagePath!),
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
                // Tall (mis-oriented) castles used to overflow; shrink to fit.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: InteractiveModalWidget(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: CastleTilesGrid(
                          castleTiles,
                          scaleWithScreen: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text('Is this correct?',
            style: TextStyle(
              fontSize: 24,
            ),
          ),
          ButtonPadding(),
          Row(
            children: [
              Consumer<CameraStore>(
                builder: (_, cameraStore, __) => FloatingActionButton.extended(
                heroTag: 'picture',
                backgroundColor: Colors.redAccent,
                icon: Icon(Icons.camera_alt),
                label: Text('No, Redo'),
                onPressed: () => NavigationHelper.goToCameraExperience(
                  context,
                  addCastleCallback: addCastleCallback,
                  numPicturesTaken: numPicturesTaken,
                  replace: true,
                  cameraTech: cameraStore.cameraTech,
                  gameTitle: gameTitle,
                )
              )),
              Flexible(child: Container()),
              FloatingActionButton.extended(
                heroTag: 'edit',
                backgroundColor: Colors.redAccent,
                icon: Icon(Icons.edit),
                label: Text('No, Edit'),
                onPressed: () {
                  NavigationHelper.goToCastleBuilderScreen(context, 
                    castleTiles: castleTiles,  
                    imagePath: imagePath,
                    replace: true,
                    addCastleCallback: addCastleCallback,
                    numPicturesTaken: numPicturesTaken,
                    gameTitle: gameTitle,
                  );
                }
              ),
              Flexible(child: Container()),
              FloatingActionButton.extended(
                heroTag: 'castle',
                backgroundColor: Colors.green,
                icon: Icon(Icons.check),
                label: Text('Yes'),
                onPressed: () async {
                  var castle = Castle(castleTiles);
                  await addCastleCallback(castle, imagePath ?? '', numPicturesTaken);
                  Analytics.logCastleSavedFromPicture(numPicturesTaken);
                  OrientationHelper.lockPortrait();
                  Navigator.pop(context);
                }
              ),
            ]
          ),
          ButtonPadding(),
        ],
      ),
    ),
    );
  }
}
