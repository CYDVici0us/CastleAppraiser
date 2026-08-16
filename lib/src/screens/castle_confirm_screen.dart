import 'dart:io';

import 'package:btcc/src/analytics/analytics.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/state/camera_store.dart';
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

  CastleConfirmScreen({
    required this.castleTiles,
    this.imagePath,
    required this.addCastleCallback,
    this.numPicturesTaken=0,
    this.gameTitle,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
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
          Expanded(
            child: Column(
              children: [
                InteractiveModalWidget(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height/4.5,
                          maxWidth: MediaQuery.of(context).size.width,
                        ),
                        child: Center(child: imagePath == null
                          ? SizedBox.shrink()
                          : Image.file(File(imagePath!),
                          fit: BoxFit.contain,
                        ))
                      )
                    ],
                  )
                ),
                Container(
                  child: InteractiveModalWidget(
                    child: CastleTilesGrid(castleTiles,)
                  ),
                ),
                Flexible(child: Container()),
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
      )
    )
  );
}
