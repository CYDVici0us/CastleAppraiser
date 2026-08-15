import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/state/camera_store.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'camera_screen.dart';
class PreCameraScreen extends StatelessWidget {

  final int numPicturesTaken;
  final AddCastleToGameCallback addCastleCallback;
  final String? gameTitle;
  PreCameraScreen({
    required this.addCastleCallback,
    this.numPicturesTaken=0,
    this.gameTitle,
  });

  @override
  Widget build(BuildContext context) => Consumer<CameraStore>(builder: (_, model, child) {
    if (model.readyForCameras) {
      return CameraScreen(
        cameras: model.cameras,
        addCastleCallback: addCastleCallback,
        numPicturesTaken: numPicturesTaken,
        gameTitle: gameTitle,
      );
    }

    var permissionsNeeded = Column(
      children: [
        Text('We need permission to use the camera in order take a picture of the castle.'),
        ElevatedButton(
          child: Text('Prompt a request for permission'),
          onPressed: () async => await model.requestCameraPermission()
        )
      ],
    );

    var noCamerasFound = Column(
        children: [
          Text('No cameras were found on this device. Please try restarting the app.'),
          ElevatedButton(
            child: Text('Try to get cameras again'),
            onPressed: () async => await model.initCameras()
          )
        ]
    );

    return Scaffold(
        appBar: AppBar(
          title: FlowBreadcrumb(
            segments: [gameTitle ?? 'Game', 'Camera'],
            onFirstSegmentTap: () => Navigator.of(context).pop(),
          ),
        ),
        body: BackgroundContainer(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (model.error == Error.CAMERA_PERMISSION_DENIED) permissionsNeeded,
                if (model.error == Error.NO_CAMERAS_FOUND) noCamerasFound,
              ],
            ),
          ),
        )
    );
  });
}