import 'dart:io';

import 'package:btcc/src/state/camera_store.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/analytics/analytics.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/state/tf_store.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/utils/image_helper.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/orientation_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PreCastleScreen extends StatefulWidget {
  
  final int numPicturesTaken;
  final String imagePath;
  final ImageRotation rotation;
  final AddCastleToGameCallback addCastleCallback;
  final String? gameTitle;
  final int? expectedRoomTileCount;

  PreCastleScreen({
    required this.imagePath,
    required this.addCastleCallback,
    this.rotation = ImageRotation.Normal,
    this.numPicturesTaken=0,
    this.gameTitle,
    this.expectedRoomTileCount,
  });

  @override
  createState() => new _PreCastleScreenState();
}

class _PreCastleScreenState extends State<PreCastleScreen> {


  bool loading = true;
  String? error;
  String? extra;

  @override
  void initState() {
    super.initState();

    // Let the previous camera route finish disposing CameraX before Flex.
    Future.delayed(const Duration(milliseconds: 200), () async {
      if (!mounted) return;
      await _processImage();
    });
  }

  _setError(String err, {String? ext}) {
    setState(() {
      loading = false;
      error = err;
      extra = ext;
    });

    Analytics.logPictureToCastleConversionError(err);
  }

  _processImage() async {
    setState(() {
      loading = true;
      error = null;
      extra = null;
    });

    TfStore store = Provider.of<TfStore>(context, listen: false);


    try {
      await store.prepareForScoring();
      var guesses = await store.runOnImage(
        widget.imagePath,
        expectedRoomTileCount: widget.expectedRoomTileCount,
      );

      if (mounted) {

        logNow(tag:'1convertGuessesToCastle');
        final buildResult = TfliteHelper.convertGuessesToCastleWithInfo(guesses);
        final castleTiles = buildResult.grid;
        logNow(tag:'2convertGuessesToCastle');

        if (castleTiles.items.isEmpty) {
          _setError('We did not detect any tiles in the image', ext: 'Guesses:\n${guesses.toString()}');
          return;
        }

        if (castleTiles.items.any((element) => element.tileType == TileType.ThroneRoom)) {
          NavigationHelper.goToCastleConfirmScreen(context, 
            castleTiles: castleTiles,
            imagePath: widget.imagePath,
            replace: true,
            addCastleCallback: widget.addCastleCallback,
            numPicturesTaken: widget.numPicturesTaken,
            gameTitle: widget.gameTitle,
            expectedRoomTileCount: widget.expectedRoomTileCount,
            cellGuesses: buildResult.cellGuesses,
            offerGridMode: buildResult.shouldOfferGridMode(
              expectedRoomTileCount: widget.expectedRoomTileCount,
            ),
          );
          return;
        }
        else {
          _setError('We could not find a throne room in the image', ext: 'Tiles:\n${castleTiles.toString()}');
          return;
        }
      }
    }
    catch (ex, stacktrace) {
      log(stacktrace.toString());
      _setError(ex.toString(), ext: stacktrace.toString());
    }
  }

  void _cancelToGame() {
    OrientationHelper.lockPortrait();
    Navigator.of(context).pop();
  }

  Widget _getImageContainer(BuildContext context) {
    final isLandscapeRotation = widget.rotation == ImageRotation.NinetyClockwise
        || widget.rotation == ImageRotation.NinetyCounterClockwise;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width,
        maxHeight: MediaQuery.of(context).size.height * (isLandscapeRotation ? 0.55 : 0.45),
      ),
      child: Hero(
        tag: widget.imagePath,
        child: Image.file(
          File(widget.imagePath),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: FlowBreadcrumb(
        showHome: true,
        onHomeTap: () {
          OrientationHelper.lockPortrait();
          NavigationHelper.popToHome(context);
        },
        segments: [
          widget.gameTitle ?? 'Game',
          error != null ? 'Error' : 'Processing',
        ],
        onSegmentTap: (index) {
          if (index == 0) _cancelToGame();
        },
      ),
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel',
        onPressed: _cancelToGame,
      ),
    ),
    body: BackgroundContainer(
      child: Center(
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _getImageContainer(context),
                Container(),
                if(error != null) Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'There was an error while processing the image:\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
                if(extra != null && kDebugMode) Expanded(
                  child: ListView(
                    children: [
                      Text(extra!)
                    ],
                  )
                )
              ],
            ),
            if(loading) Align(
              alignment: Alignment.center,
              child: Hero(tag: 'progress', child: CircularProgressIndicator()),
            ),
          ],
        )
      ),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    floatingActionButton: error == null ? null : Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          FloatingActionButton.extended(
            heroTag: 'cancel',
            backgroundColor: Colors.blueGrey,
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
            onPressed: _cancelToGame,
          ),
          const Spacer(),
          Consumer<CameraStore>(
            builder: (_, cameraStore, __) => FloatingActionButton.extended(
              heroTag: 'retake',
              icon: const Icon(Icons.camera_alt),
              label: const Text('Retake'),
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
        ],
      ),
    ),
  );
}
