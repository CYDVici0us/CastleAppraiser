import 'dart:io';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/statistics_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/async_confirmation_dialog.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/castle/castle_image.dart';
import 'package:btcc/src/widgets/castle/castle_tiles_grid.dart';
import 'package:btcc/src/widgets/castle/score_card_widget.dart';
import 'package:btcc/src/widgets/castle/tile_score_grid.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:btcc/src/widgets/interactive_modal.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

class CastleScreen extends StatelessWidget {

  final Castle castle;
  final bool onlyShowScoreCard;
  final DeleteCastleCallback? deleteCastleCallback;
  final VoidCallback? editCastleCallback;
  final VoidCallback? renameCastleCallback;
  final String? gameTitle;

  CastleScreen({
    required this.castle,
    this.onlyShowScoreCard=false,
    this.deleteCastleCallback,
    this.editCastleCallback,
    this.renameCastleCallback,
    this.gameTitle,
  });

  _onDeletePress(BuildContext context) {
    var deleted = false;
    showDialog(
      context: context,
      builder: (_) => AsyncConfirmationDialog(
        confirmationText: 'Are you sure you want to delete this castle?',
        progressText: 'Deleting castle...',
        popOnYes: true,
        onPressedYes: () async {
          await deleteCastleCallback!(castle);
          deleted = true;
          return 'Successfully deleted castle!';
        },
      )
    ).then((_) {
      if (deleted && context.mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  _onModalFabPressed(BuildContext context, ScreenshotController controller) {
    showDialog(
      context: context,
      builder: (_) => AsyncConfirmationDialog(
        confirmationText: 'Save this castle image to your phone\'s gallery?',
        progressText: 'Saving image...',
        onPressedYes: () async {
          var directory = (await getApplicationDocumentsDirectory()).path;
          String fileName = '${castle.title}_${DateTime.now().microsecondsSinceEpoch}.png';
          double pixelRatio = MediaQuery.of(context).devicePixelRatio;
          String result = '';
          String resultPath = '';

          log('Saving widget screenshot image for $fileName with res of $pixelRatio');
          try {
            if (Platform.isWindows) {
              resultPath = await controller.captureAndSave(
                directory,
                fileName: fileName,
                pixelRatio: 1.75 * pixelRatio,
              ) ?? '';
              result = 'Saved widget screenshot image of castle to $resultPath';
            }
            else {
              var res = await controller.capture(
                pixelRatio: 3 * pixelRatio,
              );
              if (res == null) {
                throw Exception('Failed to capture screenshot');
              }
              await Gal.putImageBytes(res, name: fileName);
              resultPath = fileName;
              result = 'Saved image to gallery successfully!';
            }
          } catch (exception) {
            result = 'Error: $exception';
          }

          log('$result at $resultPath');
          return result;
        },
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = castle.hiveCastle?.title ?? castle.title;
    return Scaffold(
      appBar: AppBar(
        title: FlowBreadcrumb(
          segments: [
            if (gameTitle != null) gameTitle!,
            '$title: ${castle.getScore()}',
          ],
          onFirstSegmentTap: gameTitle == null
              ? null
              : () => Navigator.of(context).pop(),
        ),
        actions: [
          if (renameCastleCallback != null) IconButton(
            icon: Icon(Icons.drive_file_rename_outline),
            tooltip: 'Rename',
            onPressed: () {
              renameCastleCallback!();
            },
          ),
          if (editCastleCallback != null) IconButton(
            icon: Icon(Icons.edit),
            tooltip: 'Edit tiles',
            onPressed: () {
              final cb = editCastleCallback!;
              Navigator.of(context).pop();
              cb();
            },
          ),
          if (deleteCastleCallback != null) IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _onDeletePress(context),
          )
        ],
      ),
      body: BackgroundContainer(
        child: ScrollConfiguration(
          behavior: ScrollBehavior(),
          child: GlowingOverscrollIndicator(
            axisDirection: AxisDirection.down,
            color: StatHelper.getColorBasedOnScore(castle.getScore()),
            child: ListView(
              children: [
                if(!onlyShowScoreCard) InteractiveModalWidget(
                  child: CastleImage(castle),
                ),
                if(!onlyShowScoreCard) InteractiveModalWidget(
                  child: CastleTilesGrid(castle.castleTiles),
                  builder: (controller) => FloatingActionButton(
                    child: Icon(Icons.screenshot),
                    onPressed: () => _onModalFabPressed(context, controller),
                  ),
                ),
                TileScoreGrid(castle),
                ScoreCardWidget(castle),
              ]
            ),
          )
        )
      )
    );
  }
}
