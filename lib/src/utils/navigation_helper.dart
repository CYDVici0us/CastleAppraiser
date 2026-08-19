
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/screens/native_camera_wait_screen.dart';
import 'package:btcc/src/screens/castle_builder_screen.dart';
import 'package:btcc/src/screens/castle_confirm_screen.dart';
import 'package:btcc/src/screens/castle_frame_screen.dart';
import 'package:btcc/src/screens/castle_screen.dart';
import 'package:btcc/src/screens/debug_ml_screen.dart';
import 'package:btcc/src/screens/debug_asset_picker_screen.dart';
import 'package:btcc/src/screens/game_edit_screen.dart';
import 'package:btcc/src/screens/photo_workflow_screen.dart';
import 'package:btcc/src/screens/pre_camera_screen.dart';
import 'package:btcc/src/screens/pre_castle_screen.dart';
import 'package:btcc/src/screens/tile_selection_flow_screen.dart';
import 'package:btcc/src/state/camera_store.dart';
import 'package:btcc/src/tflite/cell_guess_info.dart';
import 'package:btcc/src/utils/orientation_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:flutter/material.dart';

import 'grid_expander.dart';
import 'image_helper.dart';

class NavigationHelper {

  static goToCameraExperience(BuildContext context, {
    int numPicturesTaken=0,
    bool replace=false,
    required CameraTech cameraTech,
    required AddCastleToGameCallback addCastleCallback,
    String? gameTitle,
  }) {
    OrientationHelper.lockPortrait();
    MaterialPageRoute<Null> route;
    if (cameraTech == CameraTech.NATIVE) {
      // Native path still opens the system camera immediately.
      OrientationHelper.unlockForCamera();
      route = MaterialPageRoute<Null>(
        builder: (_) => NativeCameraWaitScreen(
          addCastleCallback: addCastleCallback,
          numPicturesTaken: numPicturesTaken,
          gameTitle: gameTitle,
        )
      );
    }
    else {
      // Plugin path: chooser first (gallery without CameraX).
      route = MaterialPageRoute<Null>(
        builder: (_) => PreCameraScreen(
          addCastleCallback: addCastleCallback,
          numPicturesTaken: numPicturesTaken,
          gameTitle: gameTitle,
        )
      );
    }
    _goTo(context, route, replace: replace);
  }

  static goToGameEditScreen(BuildContext context, {
    bool replace=false,
    Game? game,
  }) {
    OrientationHelper.lockPortrait();
    var route = MaterialPageRoute<Null>(
      builder: (_) => GameEditScreen(game: game),
    );
    _goTo(context, route, replace: replace);
  }

  static goToCastleConfirmScreen(BuildContext context, {
    required GridList<Tile> castleTiles,
    required AddCastleToGameCallback addCastleCallback,
    String? imagePath, 
    bool replace=false,
    int numPicturesTaken = 0,
    String? gameTitle,
    int? expectedRoomTileCount,
    Map<int, CellGuessInfo>? cellGuesses,
    bool offerGridMode = false,
  }) {
    var route = MaterialPageRoute<Null>(
      builder: (_) => CastleConfirmScreen(
        castleTiles: castleTiles, 
        imagePath: imagePath,
        addCastleCallback: addCastleCallback,
        numPicturesTaken: numPicturesTaken,
        gameTitle: gameTitle,
        expectedRoomTileCount: expectedRoomTileCount,
        cellGuesses: cellGuesses,
        offerGridMode: offerGridMode,
      )
    );
    _goTo(context, route, replace: replace);
  }

  static goToCastleScreen(BuildContext context, Castle castle, {
    bool replace=false,
    bool onlyShowScoreCard=false,
    VoidCallback? renameCastleCallback,
    String? gameTitle,
  }) {
    var route = MaterialPageRoute<Null>(
        builder: (_) => CastleScreen(
          castle: castle,
          onlyShowScoreCard: onlyShowScoreCard,
          renameCastleCallback: renameCastleCallback,
          gameTitle: gameTitle,
        )
    );
    _goTo(context, route, replace: replace);
  }

  static goToPhotoWorkflowScreen(
    BuildContext context,
    String imagePath, {
    ImageRotation rotation = ImageRotation.Normal,
    bool replace = false,
    int numPicturesTaken = 0,
    required AddCastleToGameCallback addCastleCallback,
    String? gameTitle,
  }) {
    OrientationHelper.lockPortrait();
    final route = MaterialPageRoute<Null>(
      builder: (_) => PhotoWorkflowScreen(
        imagePath: imagePath,
        rotation: rotation,
        addCastleCallback: addCastleCallback,
        numPicturesTaken: numPicturesTaken,
        gameTitle: gameTitle,
      ),
    );
    _goTo(context, route, replace: replace);
  }

  static goToTileSelectionFlowScreen(
    BuildContext context,
    String imagePath, {
    bool replace = false,
    int numPicturesTaken = 0,
    required AddCastleToGameCallback addCastleCallback,
    String? gameTitle,
    int? expectedRoomTileCount,
  }) {
    OrientationHelper.lockPortrait();
    final route = MaterialPageRoute<Null>(
      builder: (_) => TileSelectionFlowScreen(
        imagePath: imagePath,
        addCastleCallback: addCastleCallback,
        numPicturesTaken: numPicturesTaken,
        gameTitle: gameTitle,
        expectedRoomTileCount: expectedRoomTileCount,
      ),
    );
    _goTo(context, route, replace: replace);
  }

  static goToCastleFrameScreen(BuildContext context, String imagePath, {
    ImageRotation rotation = ImageRotation.Normal,
    bool replace = false,
    int numPicturesTaken = 0,
    required AddCastleToGameCallback addCastleCallback,
    String? gameTitle,
    int? expectedRoomTileCount,
  }) {
    OrientationHelper.lockPortrait();
    final route = MaterialPageRoute<Null>(
      builder: (_) => CastleFrameScreen(
        imagePath: imagePath,
        rotation: rotation,
        addCastleCallback: addCastleCallback,
        numPicturesTaken: numPicturesTaken,
        gameTitle: gameTitle,
        expectedRoomTileCount: expectedRoomTileCount,
      ),
    );
    _goTo(context, route, replace: replace);
  }

  static goToPreCastleScreen(BuildContext context, String imagePath, {
    ImageRotation rotation=ImageRotation.Normal,
    bool replace=false,
    int numPicturesTaken = 0,
    required AddCastleToGameCallback addCastleCallback,
    String? gameTitle,
    int? expectedRoomTileCount,
  }) {
    var route = MaterialPageRoute<Null>(
        builder: (_) => PreCastleScreen(
          imagePath: imagePath, 
          rotation: rotation,
          addCastleCallback: addCastleCallback,
          numPicturesTaken: numPicturesTaken,
          gameTitle: gameTitle,
          expectedRoomTileCount: expectedRoomTileCount,
        )
    );
    _goTo(context, route, replace: replace);
  }

  static goToCastleBuilderScreen(BuildContext context, {
    required GridList<Tile> castleTiles,
    String? imagePath,
    bool replace=false,
    int numPicturesTaken=0,
    AddCastleToGameCallback? addCastleCallback,
    UpdateCastleCallback? updateCastleCallback,
    Castle? existingCastle,
    String? gameTitle,
    bool readOnly=false,
  }) {
    assert(readOnly || addCastleCallback != null || updateCastleCallback != null);
    var route = MaterialPageRoute<Null>(
        builder: (_) => CastleBuilderScreen(
          castleTiles: castleTiles,
          imagePath: imagePath,
          addCastleCallback: addCastleCallback,
          updateCastleCallback: updateCastleCallback,
          existingCastle: existingCastle,
          numPicturesTaken: numPicturesTaken,
          gameTitle: gameTitle,
          readOnly: readOnly,
        )
    );
    _goTo(context, route, replace: replace);
  }

  static goToDebugMlScreen(BuildContext context, {String? imagePath, bool replace=false}) {
    var route = MaterialPageRoute<Null>(
        builder: (_) => DebugMLScreen(imagePath)
    );
    _goTo(context, route, replace: replace);
  }

  static goToDebugAssetPickerScreen(
    BuildContext context, {
    required AddCastleToGameCallback addCastleCallback,
    required String gameTitle,
    required ValueChanged<String> onAssetChosen,
    bool replace = false,
  }) {
    final route = MaterialPageRoute<Null>(
      builder: (_) => DebugAssetPickerScreen(
        addCastleCallback: addCastleCallback,
        gameTitle: gameTitle,
        onAssetChosen: onAssetChosen,
      ),
    );
    _goTo(context, route, replace: replace);
  }

  static _goTo(BuildContext context, MaterialPageRoute route, {bool replace=false}) {
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    }
    else {
      Navigator.of(context).push(route);
    }
  }

  /// Pop to the root (main / Home) screen.
  static void popToHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
