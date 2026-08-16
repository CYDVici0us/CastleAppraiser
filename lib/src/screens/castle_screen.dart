import 'dart:io';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/statistics_helper.dart';
import 'package:btcc/src/widgets/async_confirmation_dialog.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/castle/castle_export_card.dart';
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
import 'package:share_plus/share_plus.dart';

class CastleScreen extends StatelessWidget {

  final Castle castle;
  final bool onlyShowScoreCard;
  final VoidCallback? renameCastleCallback;
  final String? gameTitle;

  CastleScreen({
    required this.castle,
    this.onlyShowScoreCard=false,
    this.renameCastleCallback,
    this.gameTitle,
  });

  void _openCastleView(BuildContext context) {
    NavigationHelper.goToCastleBuilderScreen(
      context,
      castleTiles: castle.castleTiles,
      imagePath: castle.hiveCastle?.imagePath,
      existingCastle: castle,
      gameTitle: gameTitle,
      readOnly: true,
    );
  }

  void _openShareModal(BuildContext context) {
    final controller = ScreenshotController();
    Navigator.of(context).push(InteractiveModal(
      CastleExportCard(castle: castle),
      controller,
      (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'share_castle',
            tooltip: 'Share',
            child: const Icon(Icons.share),
            onPressed: () => _onSharePressed(context, c),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'save_castle',
            tooltip: 'Save',
            child: const Icon(Icons.download),
            onPressed: () => _onSavePressed(context, c),
          ),
        ],
      ),
    ));
  }

  Future<void> _onSharePressed(
    BuildContext context,
    ScreenshotController controller,
  ) async {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    try {
      final bytes = await controller.capture(
        pixelRatio: Platform.isWindows ? 1.75 * pixelRatio : 3 * pixelRatio,
      );
      if (bytes == null) {
        throw Exception('Failed to capture screenshot');
      }
      final directory = await getTemporaryDirectory();
      final fileName =
          '${castle.title}_${DateTime.now().microsecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: castle.hiveCastle?.title ?? castle.title,
        ),
      );
    } catch (exception) {
      log('Error sharing castle image: $exception');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share image: $exception')),
        );
      }
    }
  }

  void _onSavePressed(BuildContext context, ScreenshotController controller) {
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

  Widget _sectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = castle.hiveCastle?.title ?? castle.title;
    final totalScore = castle.getScore();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: FlowBreadcrumb(
          showHome: true,
          onHomeTap: () => NavigationHelper.popToHome(context),
          segments: [
            if (gameTitle != null) gameTitle!,
            title,
          ],
          onSegmentTap: gameTitle == null
              ? null
              : (index) {
                  if (index == 0) Navigator.of(context).pop();
                },
        ),
        actions: [
          if (renameCastleCallback != null) IconButton(
            icon: Icon(Icons.drive_file_rename_outline),
            tooltip: 'Rename',
            onPressed: () {
              renameCastleCallback!();
            },
          ),
          if (!onlyShowScoreCard) IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () => _openShareModal(context),
          ),
        ],
      ),
      body: BackgroundContainer(
        child: ScrollConfiguration(
          behavior: ScrollBehavior(),
          child: GlowingOverscrollIndicator(
            axisDirection: AxisDirection.down,
            color: StatHelper.getColorBasedOnScore(totalScore),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalScore',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: StatHelper.getColorBasedOnScore(totalScore),
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!onlyShowScoreCard) ...[
                  InkWell(
                    onTap: () => _openCastleView(context),
                    child: CastleImage(castle),
                  ),
                  InkWell(
                    onTap: () => _openCastleView(context),
                    child: CastleTilesGrid(castle.castleTiles),
                  ),
                ],
                _sectionHeader(context, 'Points per tile'),
                TileScoreGrid(castle),
                _sectionHeader(context, 'Tiles by category'),
                ScoreCardWidget(castle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
